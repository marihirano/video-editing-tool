import AVFoundation
import AppKit
import EditorCore

/// Temporary: VET_DEBUG_PROJECT=<.vetproj> VET_DEBUG_OUT=<dir> exports the project and saves frames.
enum DebugDump {
    static func run() async throws -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["VET_DEBUG_PROJECT"], let dir = env["VET_DEBUG_OUT"] else { return false }
        var (project, source) = try ProjectStore.load(from: URL(fileURLWithPath: path))
        let a = Double(env["VET_DEBUG_FROM"] ?? "0")!, b = Double(env["VET_DEBUG_TO"] ?? "1")!
        project.timeline.clips = [Clip(start: a, end: b)]
        project.timeline.zooms = project.timeline.zooms   // zooms keep source times
        let out = URL(fileURLWithPath: dir).appendingPathComponent("dbg.mp4")
        try await Exporter().export(project: project, sourceURL: source, to: out) { _ in }
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: out))
        g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
        let n = Int(env["VET_DEBUG_FRAMES"] ?? "12")!, step = Double(env["VET_DEBUG_STEP"] ?? "0.0166667")!
        let t0 = Double(env["VET_DEBUG_T0"] ?? "0")!
        for i in 0..<n {
            let (img, _) = try await g.image(at: CMTime(seconds: t0 + Double(i) * step, preferredTimescale: 6000))
            try NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent(String(format: "f%03d.png", i)))
        }
        return true
    }
}
