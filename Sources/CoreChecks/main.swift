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

print("Renderer")
check(MetalContext.shared != nil, "Metal shaders compile at startup")
let u = FrameLayout.uniforms(project: Project(source: SourceVideo(path: "", width: 1440, height: 900, duration: 1)),
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
}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
