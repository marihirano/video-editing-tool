import AppKit
import AVFoundation
import EditorCore
import Foundation

// Plain-program checks for the core. Run: swift run CoreChecks
var failures = 0
func check(_ ok: Bool, _ what: String) {
    print(ok ? "  ok   \(what)" : "  FAIL \(what)")
    if !ok { failures += 1 }
}
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("vet-checks-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

print("Project file")
do {
    let source = tmp.appendingPathComponent("clip.mov")
    try Data("x".utf8).write(to: source)
    let package = tmp.appendingPathComponent("Demo.\(Settings.projectExtension)")
    try ProjectStore.save(Project(source: SourceVideo(path: source.path, width: 2880, height: 1800, duration: 3)),
                          sourceURL: source, to: package)
    let json = try String(contentsOf: package.appendingPathComponent(Settings.projectFileName), encoding: .utf8)
    check(json.contains("\"cursor\""), "project.json has the cursor slot")
    check(json.contains("\"relativePath\" : \"clip.mov\""), "source saved relative to the project")
    let (loaded, url) = try ProjectStore.load(from: package)
    check(url.standardizedFileURL.path == source.standardizedFileURL.path, "reopen finds the source video")
    check(loaded.output.width == 1920 && loaded.output.height == 1080, "output defaults to 1080p")

    let minimal = #"{"source":{"path":"/x.mov","width":10,"height":10,"duration":1}}"#
    let p = try JSONDecoder().decode(Project.self, from: Data(minimal.utf8))
    check(p.output.fps == Settings.defaultOutputFPS && p.timeline.cuts.isEmpty, "older or partial files still open")
}

print("Style")
do {
    var st = FrameStyle()
    st.kind = .image; st.imagePath = "/tmp/x.png"; st.padding = 12.5; st.cornerRadius = 30
    st.shadowOpacity = 0.7; st.shadowBlur = 55; st.shadowOffset = 9; st.wallpaper = 3
    st.gradientStart = RGBAColor(hex: 0x123456); st.gradientAngle = 200
    var proj = Project(source: SourceVideo(path: "/x.mov", width: 10, height: 10, duration: 1))
    proj.style = st
    let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(proj))
    check(back.style == st, "style survives save and reopen")

    let m1 = #"{"source":{"path":"/x.mov","width":10,"height":10,"duration":1},"style":{"background":{"r":0,"g":0,"b":0,"a":1}}}"#
    let old = try JSONDecoder().decode(Project.self, from: Data(m1.utf8))
    check(old.style.padding == Settings.defaultPadding && old.style.cornerRadius == Settings.defaultCornerRadius
          && old.style.kind == Settings.defaultBackgroundKind && old.style.background.r == 0,
          "M1 project (only `background`) opens with default look")

    var padded = Project(source: SourceVideo(path: "", width: 1440, height: 900, duration: 1))
    padded.style.padding = 10
    let pu = FrameLayout.uniforms(project: padded, sourceSize: CGSize(width: 1440, height: 900), sourceTime: 0)
    check(abs(pu.contentRect.y - 0.1) < 1e-5 && abs(pu.contentRect.w - 0.8) < 1e-5, "10% padding leaves 10% free above and below")
}

print("Renderer")
check(MetalContext.shared != nil, "Metal shaders compile at startup")
var plain = Project(source: SourceVideo(path: "", width: 1440, height: 900, duration: 1))
plain.style.padding = 0
let u = FrameLayout.uniforms(project: plain,
                             sourceSize: CGSize(width: 1440, height: 900), sourceTime: 0)
check(abs(u.contentRect.z - Float(1.6 / (16.0 / 9.0))) < 1e-5 && u.contentRect.w == 1, "16:10 video fits a 16:9 canvas, centred")

print("Export")
do {
    let source = tmp.appendingPathComponent("source.mov")
    try await TestVideo.make(at: source, width: 1440, height: 900, seconds: 2, fps: 30)
    let info = try await VideoInfo.load(source)
    check(info.width == 1440 && abs(info.duration - 2) < 0.05, "reads the test video")

    let out = tmp.appendingPathComponent("out.mp4")
    let exporter = Exporter()
    let start = Date()
    try await exporter.export(project: Project(source: info.sourceVideo), sourceURL: source, to: out) { _ in }
    let asset = AVURLAsset(url: out)
    let video = try await asset.loadTracks(withMediaType: .video)
    let audio = try await asset.loadTracks(withMediaType: .audio)
    let size = try await video[0].load(.naturalSize)
    let duration = try await asset.load(.duration).seconds
    let frames = try await video[0].load(.nominalFrameRate)
    check(size == CGSize(width: 1920, height: 1080), "MP4 is 1920×1080")
    check(abs(duration - 2) < 0.05, "MP4 is 2 seconds long (\(duration))")
    check(audio.isEmpty, "MP4 is silent")
    check(exporter.usedHardwareEncoder, "hardware encoder used")
    print(String(format: "  info took %.2fs, %.0f fps, file: %@", Date().timeIntervalSince(start), frames, out.path))

    if let dir = ProcessInfo.processInfo.environment["VET_CHECK_FRAME_DIR"] {
        let g = AVAssetImageGenerator(asset: asset)
        let (img, _) = try await g.image(at: CMTime(seconds: 1, preferredTimescale: 60))
        try NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("default-frame.png"))
    }
    // A styled export: 10% padding, big corners, plain magenta background, no shadow.
    var styled = Project(source: info.sourceVideo)
    styled.style.kind = .solid
    styled.style.background = RGBAColor(r: 1, g: 0, b: 1, a: 1)
    styled.style.padding = 10; styled.style.cornerRadius = 60; styled.style.shadowOpacity = 0
    let out2 = tmp.appendingPathComponent("styled.mp4")
    try await Exporter().export(project: styled, sourceURL: source, to: out2) { _ in }
    let gen = AVAssetImageGenerator(asset: AVURLAsset(url: out2))
    gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
    let (cg, _) = try await gen.image(at: .zero)
    if let dir = ProcessInfo.processInfo.environment["VET_CHECK_FRAME_DIR"] {
        let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        try png?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("styled-frame.png"))
    }
    func pixel(_ x: Int, _ y: Int) -> (Int, Int, Int) {
        let rep = NSBitmapImageRep(cgImage: cg)
        let c = rep.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
        return (Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
    func near(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Bool {
        abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2) < 90
    }
    check(near(pixel(5, 5), (255, 0, 255)), "styled export: canvas corner is background")
    check(near(pixel(272, 112), (255, 0, 255)), "styled export: video's corner is rounded off")
    check(near(pixel(960, 540), (0, 194, 208)), "styled export: video fills the middle")
    check(near(pixel(100, 540), (255, 0, 255)), "styled export: padding strip is background")
}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
