import AppKit

/// For Claude's checks: launched with VET_SNAPSHOT=/path.png (and a video to open), the app
/// saves a picture of its window, logs whether the preview drew video, and quits.
/// The Metal preview itself shows as blank in this picture; only the layout around it is captured.
@MainActor
enum DebugSnapshot {
    static func runIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["VET_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let model = EditorModel.shared
            model.playback.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let view = NSApp.windows.first(where: { $0.isVisible })?.contentView,
                   let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                }
                let line = "project=\(model.project != nil) playing=\(model.playback.isPlaying) time=\(model.playback.currentTime) videoFramesDrawn=\(model.drawer?.videoFramesDrawn ?? -1)\n"
                try? line.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
                NSApp.terminate(nil)
            }
        }
    }
}
