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

            Button { model.splitAtEditPoint() } label: {
                Image(systemName: "scissors").font(.system(size: 17))
            }
            .buttonStyle(.plain)
            .help("Split the clip at the blue line (⌘B)")
            Spacer()
        }
    }

    static func format(_ seconds: Double) -> String {
        let s = Int(max(seconds, 0).rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
