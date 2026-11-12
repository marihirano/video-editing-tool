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
    check(p.output.fps == Settings.defaultOutputFPS && p.timeline.clips.isEmpty, "older or partial files still open")
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
    let pu = FrameLayout.uniforms(project: padded, sourceSize: CGSize(width: 1440, height: 900), outputTime: 0)
    check(abs(pu.contentRect.y - 0.1) < 1e-5 && abs(pu.contentRect.w - 0.8) < 1e-5, "10% padding leaves 10% free above and below")
}

print("Timeline")
do {
    func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-6 }
    var tl = Timeline()
    check(tl.resolvedClips(sourceDuration: 10) == [Clip(start: 0, end: 10)], "no edits: one clip, the whole recording")
    check(near(TimeMap(timeline: tl, sourceDuration: 10).outputDuration, 10), "no edits: video is as long as the recording")
    // Split at 1, 3, 4, 5, 7, 9 → clips 0–1 | 1–3 | 3–4 | 4–5 | 5–7 | 7–9 | 9–10
    for at in [1.0, 3, 4, 5, 7, 9] { tl.split(atOutput: at, sourceDuration: 10) }
    check(tl.clips.count == 7, "six splits make seven clips")
    check(!tl.split(atOutput: 3.05, sourceDuration: 10), "a split right next to another is refused")
    tl.deleteClip(6, sourceDuration: 10)       // drop 9–10
    tl.deleteClip(2, sourceDuration: 10)       // drop 3–4
    tl.deleteClip(0, sourceDuration: 10)       // drop 0–1 → 1–3 | 4–5 | 5–7 | 7–9  (7 s)
    tl.setRate(4, ofClip: 2, sourceDuration: 10)  // 5–7 at 4× → 0.5 s → 5.5 s
    let map = TimeMap(timeline: tl, sourceDuration: 10)
    check(near(map.outputDuration, 5.5), "delete three clips + one at 4×: 5.5 s long (\(map.outputDuration))")
    check(near(map.sourceTime(forOutput: 0), 1), "video starts at the first kept clip")
    check(near(map.sourceTime(forOutput: 2.5), 4.5), "jumps over a deleted clip")
    check(near(map.sourceTime(forOutput: 3.25), 6), "sped-up clip runs 4× faster")
    check(near(map.sourceTime(forOutput: 5.5), 9), "video ends with the last clip")
    check(near(map.outputTime(forSource: 3.5), 2), "a deleted moment maps to where the video carries on")
    check(map.pieceIndex(atOutput: 3.0) == 2, "finds the clip under a timeline position")
    var last = -1.0, monotonic = true
    for i in 0...550 { let s = map.sourceTime(forOutput: Double(i) / 100); if s < last - 1e-9 { monotonic = false }; last = s }
    check(monotonic, "source time never goes backwards")
    var one = Timeline(); one.deleteClip(0, sourceDuration: 10)
    check(one.resolvedClips(sourceDuration: 10).count == 1, "the last clip can't be deleted")

    var proj = Project(source: SourceVideo(path: "/x.mov", width: 10, height: 10, duration: 10))
    proj.timeline = tl
    let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(proj))
    check(back.timeline == tl, "clips and speeds survive save and reopen")

    let m3 = #"{"source":{"path":"/x.mov","width":10,"height":10,"duration":10},"timeline":{"trim":{"start":1,"end":9},"cuts":[{"start":3,"end":4}],"speedSegments":[{"range":{"start":5,"end":7},"rate":4}]}}"#
    let old = try JSONDecoder().decode(Project.self, from: Data(m3.utf8))
    check(near(TimeMap(project: old, sourceDuration: 10).outputDuration, 5.5), "first-M3 files (trim, cuts, speed) open as clips")

    var h = UndoHistory<Int>()
    let t0 = Date()
    h.record(0, group: "style", now: t0); h.record(1, group: "style", now: t0 + 0.1); h.record(2, group: "style", now: t0 + 0.2)
    h.record(3, now: t0 + 0.3)
    check(h.undo(current: 4) == 3 && h.undo(current: 3) == 0 && !h.canUndo, "one slider drag is one undo step")
    check(h.redo(current: 0) == 3 && h.redo(current: 3) == 4 && !h.canRedo, "redo brings edits back")
}

print("Zoom and crop")
do {
    func near(_ a: Double, _ b: Double, _ tol: Double = 1e-6) -> Bool { abs(a - b) < tol }
    // Easing curve shape.
    check(Spring.value(0, bounce: 0) == 0 && near(Spring.value(1, bounce: 0), 1), "easing starts at 0 and ends at 1")
    check(Spring.value(0.03, bounce: 0) < 0.03, "easing starts at rest (slow first moment)")
    check(Spring.value(0.5, bounce: 0) > 0.75, "easing is mostly there by halfway (spring feel)")
    var mono = true, prev = -1.0
    for i in 0...200 { let v = Spring.value(Double(i) / 200, bounce: 0); if v < prev - 1e-12 || v > 1 + 1e-9 { mono = false }; prev = v }
    check(mono, "no bounce: never goes backwards or past 1")
    let peak = (0...200).map { Spring.value(Double($0) / 200, bounce: 1) }.max()!
    check(peak > 1.05 && peak < 1.25 && near(Spring.value(1, bounce: 1), 1), "full bounce overshoots a little, then lands on 1 (peak \(String(format: "%.3f", peak)))")

    // Placement: zoom at 6–8 s of a 10 s recording.
    var tl = Timeline()
    tl.zooms = [ZoomSegment(range: TimeRange(start: 6, end: 8), centerX: 0.25, centerY: 0.75, scale: 2)]
    for at in [2.0, 4.0, 9.0] { tl.split(atOutput: at, sourceDuration: 10) }   // 0–2 | 2–4 | 4–9 | 9–10
    tl.deleteClip(1, sourceDuration: 10)                                         // drop 2–4
    var map = TimeMap(timeline: tl, sourceDuration: 10)
    var r = tl.zoomOutputRanges(map)[0]
    check(near(r.start, 4) && near(r.end, 6), "deleting an earlier clip moves the zoom with its content (\(r.start)–\(r.end))")
    tl.setRate(2, ofClip: 1, sourceDuration: 10)                                 // 4–9 at 2×
    map = TimeMap(timeline: tl, sourceDuration: 10)
    r = tl.zoomOutputRanges(map)[0]
    check(near(r.start, 3) && near(r.end, 4), "speeding up its clip shortens the zoom in the video (\(r.start)–\(r.end))")
    tl.zooms.append(ZoomSegment(range: TimeRange(start: 0.5, end: 1.5)))
    tl.deleteClip(0, sourceDuration: 10)                                         // drop 0–2 with its zoom
    check(tl.zooms.count == 1 && tl.zooms[0].scale == 2, "a zoom on a deleted clip goes with it")

    // Add / move / resize on the finished video's clock, never overlapping.
    var t2 = Timeline()
    let m2 = TimeMap(timeline: t2, sourceDuration: 10)
    let a = t2.addZoom(fromOutput: 2, to: 4, map: m2)
    let b = t2.addZoom(fromOutput: 7, to: 5, map: m2)
    check(a == 0 && b == 1 && t2.zooms.count == 2, "drag adds zooms (either direction)")
    check(t2.addZoom(fromOutput: 3, to: 3.5, map: m2) == nil, "can't add a zoom on top of another")
    t2.addZoom(fromOutput: 4.1, to: 9, map: m2)
    check(t2.zooms.count == 3 && near(t2.zooms[1].range.end, 5), "a new zoom stops at the next zoom")
    t2.deleteZoom(1)
    t2.moveZoom(0, toOutputStart: 6, map: m2)
    check(near(t2.zooms[0].range.start, 3) && near(t2.zooms[0].range.end, 5), "moving stops at the neighbour and keeps the length")
    t2.resizeZoom(0, startEdge: true, toOutput: 4.95, map: m2)
    check(near(t2.zooms[0].range.start, 5 - Settings.minimumZoomSeconds), "resizing keeps the minimum length")
    t2.resizeZoom(0, startEdge: true, toOutput: -3, map: m2)
    check(near(t2.zooms[0].range.start, 0), "resizing stops at the start of the video")

    // Camera.
    let cam = ZoomCamera(zooms: [ZoomSegment(range: TimeRange(start: 1, end: 5), centerX: 0.5, centerY: 0.5, scale: 2, transition: 1, bounce: 0)],
                         map: TimeMap(timeline: Timeline(), sourceDuration: 10))
    let frame = CGRect(x: 0, y: 0, width: 1000, height: 500)
    check(cam.visibleRect(atOutput: 0.5, cropped: frame) == frame, "before a zoom: whole frame")
    let mid = cam.visibleRect(atOutput: 3, cropped: frame)
    check(near(mid.width, 500, 1e-6) && near(mid.midX, 500, 1e-6) && near(mid.midY, 250, 1e-6), "fully zoomed: half the frame around the point")
    check(cam.visibleRect(atOutput: 1.5, cropped: frame).width < 1000 && cam.visibleRect(atOutput: 1.5, cropped: frame).width > 500, "halfway in: partly zoomed")
    let edge = ZoomCamera.targetRect(ZoomSegment(range: TimeRange(start: 0, end: 1), centerX: 1, centerY: 0, scale: 2), cropped: frame)
    check(edge == CGRect(x: 500, y: 0, width: 500, height: 250), "zooming at a corner stays inside the frame")

    // Save and reopen.
    var proj = Project(source: SourceVideo(path: "/x.mov", width: 1440, height: 900, duration: 10))
    proj.timeline.zooms = [ZoomSegment(range: TimeRange(start: 1, end: 3), centerX: 0.2, centerY: 0.8, scale: 2.5, transition: 0.7, bounce: 0.3)]
    proj.crop = CropRect(x: 100, y: 50, width: 800, height: 500)
    let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(proj))
    check(back.timeline.zooms == proj.timeline.zooms && back.crop == proj.crop, "zooms and crop survive save and reopen")
    let partial = #"{"source":{"path":"/x.mov","width":10,"height":10,"duration":1},"timeline":{"zooms":[{"range":{"start":0,"end":1},"centerX":0.5,"centerY":0.5,"scale":2}]}}"#
    let pz = try JSONDecoder().decode(Project.self, from: Data(partial.utf8)).timeline.zooms[0]
    check(pz.scale == 2 && pz.transition == Settings.zoomEasingPresets[Settings.defaultZoomEasing].transition, "zooms without easing fields open with the default easing")
    let cu = FrameLayout.uniforms(project: proj, sourceSize: CGSize(width: 1440, height: 900), outputTime: 0)
    check(abs(cu.sourceRect.x - Float(100.0 / 1440)) < 1e-5 && abs(cu.sourceRect.z - Float(800.0 / 1440)) < 1e-5, "crop picks the right part of the frame")
    let cw = FrameLayout.uniforms(project: proj, sourceSize: CGSize(width: 1440, height: 900), outputTime: 0, mode: .wholeFrame)
    check(cw.sourceRect == SIMD4<Float>(0, 0, 1, 1), "crop editing shows the whole recording")
}

print("Renderer")
check(MetalContext.shared != nil, "Metal shaders compile at startup")
var plain = Project(source: SourceVideo(path: "", width: 1440, height: 900, duration: 1))
plain.style.padding = 0
let u = FrameLayout.uniforms(project: plain,
                             sourceSize: CGSize(width: 1440, height: 900), outputTime: 0)
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

    // An edited export: split at 0.2, 0.6, 1.0, 1.4, 1.8; delete 0–0.2, 0.6–1.0, 1.8–2; 1.0–1.4 at 4×
    // → 0.4 + 0.1 + 0.4 = 0.9 s.
    var edited = Project(source: info.sourceVideo)
    for at in [0.2, 0.6, 1.0, 1.4, 1.8] { edited.timeline.split(atOutput: at, sourceDuration: info.duration) }
    for i in [5, 2, 0] { edited.timeline.deleteClip(i, sourceDuration: info.duration) }
    edited.timeline.setRate(4, ofClip: 1, sourceDuration: info.duration)
    let expected = TimeMap(project: edited, sourceDuration: info.duration).outputDuration
    let out3 = tmp.appendingPathComponent("edited.mp4")
    try await Exporter().export(project: edited, sourceURL: source, to: out3) { _ in }
    let editedDuration = try await AVURLAsset(url: out3).load(.duration).seconds
    check(abs(expected - 0.9) < 1e-6 && abs(editedDuration - 0.9) < 0.04, "edited export (deleted clips, 4× clip) is 0.9 s (\(editedDuration))")

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
    // Crop + zoom export: crop to the top-left 384×240 (same shape as the recording), then a 2×
    // zoom on its centre for the whole video. Green = source row, blue steps 1 per source column.
    var zoomed = Project(source: info.sourceVideo)
    zoomed.style.padding = 0; zoomed.style.cornerRadius = 0; zoomed.style.shadowOpacity = 0
    zoomed.crop = CropRect(x: 0, y: 0, width: 384, height: 240)
    let out4 = tmp.appendingPathComponent("crop.mp4"), out5 = tmp.appendingPathComponent("zoom.mp4")
    try await Exporter().export(project: zoomed, sourceURL: source, to: out4) { _ in }
    zoomed.timeline.zooms = [ZoomSegment(range: TimeRange(start: 0, end: 2), centerX: 0.5, centerY: 0.5, scale: 2, transition: 0.3, bounce: 0)]
    try await Exporter().export(project: zoomed, sourceURL: source, to: out5) { _ in }
    func rgb(_ url: URL, _ t: Double, _ points: [(Int, Int)]) async throws -> [(Double, Double, Double)] {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
        let (img, _) = try await g.image(at: CMTime(seconds: t, preferredTimescale: 600))
        let rep = NSBitmapImageRep(cgImage: img)
        if let dir = ProcessInfo.processInfo.environment["VET_CHECK_FRAME_DIR"] {
            try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-frame.png"))
        }
        return points.map { let c = rep.colorAt(x: $0.0, y: $0.1)!.usingColorSpace(.sRGB)!; return (c.redComponent * 255, c.greenComponent * 255, c.blueComponent * 255) }
    }
    // Content is 1728×1080 at x 96 in all three exports. Each output spot should show the same
    // colour as the unedited export at the source spot it comes from.
    func matches(_ url: URL, at t: Double, _ pairs: [((Int, Int), (Double, Double))]) async throws -> (Bool, String) {
        let got = try await rgb(url, t, pairs.map(\.0))
        let r = FrameLayout.contentRect(project: Project(source: info.sourceVideo), mode: .normal)   // unedited has default padding
        let want = try await rgb(out, t, pairs.map { (Int((r.minX + $0.1.0 / 1440 * r.width) * 1920), Int((r.minY + $0.1.1 / 900 * r.height) * 1080)) })
        var ok = true, report = ""
        for (g, w) in zip(got, want) {
            let d = abs(g.0 - w.0) + abs(g.1 - w.1) + abs(g.2 - w.2)
            report += String(format: " %.0f", d)
            if d > 30 { ok = false }
        }
        return (ok, report)
    }
    let (cropOK, cropR) = try await matches(out4, at: 1, [((960, 540), (192, 120)), ((960, 900), (192, 200)), ((528, 540), (96, 120)), ((1392, 540), (288, 120))])
    check(cropOK, "crop export shows the cropped part (colour differences:\(cropR))")
    let (zoomOK, zoomR) = try await matches(out5, at: 1, [((960, 540), (192, 120)), ((960, 900), (192, 160)), ((528, 540), (144, 120)), ((1392, 540), (240, 120))])
    check(zoomOK, "zoom export shows 2× around the point (colour differences:\(zoomR))")
    let (startOK, startR) = try await matches(out5, at: 0, [((960, 900), (192, 200)), ((528, 540), (96, 120))])
    check(startOK, "zoom export starts un-zoomed (colour differences:\(startR))")
}

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
