import EditorCore
import SwiftUI

/// Play/pause, the time in the finished video, the scissors (cut tool) and crop.
struct TransportBar: View {
    @EnvironmentObject private var model: EditorModel
    @EnvironmentObject private var playback: PlaybackController

    var body: some View {
        HStack(spacing: Theme.s3) {
            Button { playback.togglePlay() } label: {
                Image(systemName: playback.isPlaying ? "pause.circle" : "play.circle")
                    .font(.system(size: 22, weight: .light))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help(playback.isPlaying ? "Pause (Space)" : "Play (Space)")

            (Text(Self.format(playback.outputTime)).foregroundStyle(.primary)
             + Text(" / \(Self.format(playback.outputDuration))").foregroundStyle(Theme.secondaryText))
                .font(.system(size: 14).monospacedDigit())

            ToolButton(systemImage: "scissors", isOn: model.isCutMode,
                       help: model.isCutMode ? "Click the timeline to cut; click the scissors again (or Esc) to stop" : "Cut: turn on the scissors, then click the timeline where you want to cut") {
                model.toggleCutMode()
            }
            ToolButton(systemImage: "crop", isOn: model.isCropMode,
                       help: model.isCropMode ? "Done cropping" : "Crop: drag handles on the preview to keep only part of the recording") {
                model.toggleCropMode()
            }
            Spacer()
        }
    }

    static func format(_ seconds: Double) -> String {
        let s = Int(max(seconds, 0).rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
