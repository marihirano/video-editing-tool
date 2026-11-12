import EditorCore
import SwiftUI

/// Play/pause, the time in the finished video, and the scissors (split at the blue line).
struct TransportBar: View {
    @EnvironmentObject private var model: EditorModel
    @EnvironmentObject private var playback: PlaybackController

    var body: some View {
        HStack(spacing: 16) {
            Button { playback.togglePlay() } label: {
                Image(systemName: playback.isPlaying ? "pause.circle" : "play.circle")
                    .font(.system(size: 22, weight: .light))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help(playback.isPlaying ? "Pause (Space)" : "Play (Space)")

            (Text(Self.format(playback.outputTime)).foregroundStyle(.primary)
             + Text(" / \(Self.format(playback.outputDuration))").foregroundStyle(.secondary))
                .font(.system(size: 15).monospacedDigit())

            Button { model.toggleCutMode() } label: {
                Image(systemName: "scissors").font(.system(size: 17))
                    .foregroundStyle(model.isCutMode ? Color.white : Color.primary)
                    .frame(width: 30, height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(model.isCutMode ? Color.accentColor : .clear))
            }
            .buttonStyle(.plain)
            .help(model.isCutMode ? "Click the timeline to cut; click the scissors again (or Esc) to stop" : "Cut: turn on the scissors, then click the timeline where you want to cut")
            Spacer()
        }
    }

    static func format(_ seconds: Double) -> String {
        let s = Int(max(seconds, 0).rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
