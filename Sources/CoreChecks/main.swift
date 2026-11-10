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

print("Timeline")
do {
    func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-6 }
    var tl = Timeline()
    check(near(TimeMap(timeline: tl, sourceDuration: 10).outputDuration, 10), "no edits: video is as long as the recording")
    tl.setTrim(start: 1, end: 9, sourceDuration: 10)       // keep 1–9  (8 s)
    tl.addCut(TimeRange(start: 3, end: 4))                  // −1 s → 7 s
    tl.setSpeed(TimeRange(start: 5, end: 7), rate: 4)       // 2 s → 0.5 s → 5.5 s
    let map = TimeMap(timeline: tl, sourceDuration: 10)
    check(near(map.outputDuration, 5.5), "trim + cut + 4× speed: 5.5 s long (\(map.outputDuration))")
    check(near(map.sourceTime(forOutput: 0), 1), "video starts at the trim")
    check(near(map.sourceTime(forOutput: 2), 3) || near(map.sourceTime(forOutput: 2.0001), 4.0001), "jumps over the cut")
    check(near(map.sourceTime(forOutput: 2.5), 4.5), "carries on after the cut")
    check(near(map.sourceTime(forOutput: 3.25), 6), "sped-up part runs 4× faster")
    check(near(map.sourceTime(forOutput: 5.5), 9), "video ends at the trim")
    check(near(map.outputTime(forSource: 3.5), 2), "a cut-away moment maps to where the video carries on")
    check(near(map.outputTime(forSource: 6), 3.25), "output time from source time")
    var last = -1.0, monotonic = true
    for i in 0...550 { let s = map.sourceTime(forOutput: Double(i) / 100); if s < last - 1e-9 { monotonic = false }; last = s }
    check(monotonic, "source time never goes backwards")

    var t2 = tl
    t2.addCut(TimeRange(start: 3.5, end: 4.5))
    check(t2.cuts == [TimeRange(start: 3, end: 4.5)], "overlapping cuts merge")
    t2.setSpeed(TimeRange(start: 6, end: 8), rate: 2)
    check(t2.speedSegments.count == 2 && near(t2.speedSegments[0].range.end, 6) && t2.speedSegments[1].rate == 2,
          "new speed replaces the overlapping part of an old one")
    t2.clearEdits(in: TimeRange(start: 0, end: 10))
    check(t2.cuts.isEmpty && t2.speedSegments.isEmpty, "restore clears cuts and speed")
    t2.setTrim(start: 0, end: 10, sourceDuration: 10)
    check(t2.trim == nil, "trimming to the whole recording means no trim")

    var proj = Project(source: SourceVideo(path: "/x.mov", width: 10, height: 10, duration: 10))
    proj.timeline = tl
    let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(proj))
    check(back.timeline == tl, "trim, cuts and speed survive save and reopen")

    var h = UndoHistory<Int>()
    let t0 = Date()
    h.record(0, group: "style", now: t0); h.record(1, group: "style", now: t0 + 0.1); h.record(2, group: "style", now: t0 + 0.2)
    h.record(3, now: t0 + 0.3)
    check(h.undo(current: 4) == 3 && h.undo(current: 3) == 0 && !h.canUndo, "one slider drag is one undo step")
    check(h.redo(current: 0) == 3 && h.redo(current: 3) == 4 && !h.canRedo, "redo brings edits back")
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

    // An edited export: keep 0.2–1.8 s, cut 0.6–1.0 s, play 1.0–1.4 s at 4× → 0.4 + 0.1 + 0.4 = 0.9 s.
    var edited = Project(source: info.sourceVideo)
    edited.timeline.setTrim(start: 0.2, end: 1.8, sourceDuration: info.duration)
    edited.timeline.addCut(TimeRange(start: 0.6, end: 1.0))
    edited.timeline.setSpeed(TimeRange(start: 1.0, end: 1.4), rate: 4)
    let expected = TimeMap(project: edited, sourceDuration: info.duration).outputDuration
    let out3 = tmp.appendingPathComponent("edited.mp4")
    try await Exporter().export(project: edited, sourceURL: source, to: out3) { _ in }
    let editedDuration = try await AVURLAsset(url: out3).load(.duration).seconds
    check(abs(expected - 0.9) < 1e-6 && abs(editedDuration - 0.9) < 0.04, "trimmed, cut and sped-up export is 0.9 s (\(editedDuration))")

    // The test video changes colour every frame, so comparing the middle pixel with the unedited
    // export (same look) at the matching source moment shows each frame came from the right place.
    func redAt(_ url: URL, _ t: Double) async throws -> Double {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
        let (img, _) = try await g.image(at: CMTime(seconds: t, preferredTimescale: 600))
        return Double(NSBitmapImageRep(cgImage: img).colorAt(x: 960, y: 540)!.usingColorSpace(.sRGB)!.redComponent * 255)
    }
    var rightFrames = true, report = ""
    for (outT, srcT) in [(0.05, 0.25), (0.3, 0.5), (0.45, 1.2), (0.7, 1.6)] {
        let got = try await redAt(out3, outT), want = try await redAt(out, srcT)
        report += String(format: " %.0f/%.0f", got, want)
        if abs(got - want) > 6 { rightFrames = false }
    }
    check(rightFrames, "edited export shows the right moments (red got/expected:\(report))")
}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
