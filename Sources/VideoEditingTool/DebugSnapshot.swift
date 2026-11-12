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
            // VET_SNAPSHOT_SPLIT=1 cuts once with the scissors tool at a third of the way and pins the blue line there.
            if ProcessInfo.processInfo.environment["VET_SNAPSHOT_SPLIT"] != nil, let map = model.timeMap {
                model.startCutMode()                       // same path as the scissors button
                model.cut(atOutput: map.outputDuration / 3)
                model.selectedClip = 1
            }
            model.playback.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // The window content, plus the top bar on its own (`…-top.png`).
                let content = NSApp.windows.first(where: { $0.isVisible })?.contentView
                for (view, file) in [(content, path), (content?.superview, path + "-top.png")] {
                    guard let view, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: file))
                }
                let line = "project=\(model.project != nil) playing=\(model.playback.isPlaying) time=\(model.playback.currentTime) videoFramesDrawn=\(model.drawer?.videoFramesDrawn ?? -1)\n"
                try? line.write(toFile: path + ".txt", atomically: true, encoding: .utf8)
                NSApp.terminate(nil)
            }
        }
    }
}
