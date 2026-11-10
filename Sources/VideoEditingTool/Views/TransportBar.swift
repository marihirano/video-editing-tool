import EditorCore
import SwiftUI

/// Play/pause, the position slider, the time, and the Export button.
struct TransportBar: View {
    @EnvironmentObject private var model: EditorModel
    @EnvironmentObject private var playback: PlaybackController

    var body: some View {
        HStack(spacing: 14) {
            Button { playback.togglePlay() } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15))
                    .frame(width: 28, height: 22)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(playback.isPlaying ? "Pause (Space)" : "Play (Space)")

            Slider(value: Binding(get: { playback.currentTime }, set: { playback.seek(to: $0) }),
                   in: 0...max(playback.duration, 0.01))
                .controlSize(.small)

            Text("\(Self.format(playback.currentTime)) / \(Self.format(playback.duration))")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Button("Export MP4…") { model.startExport() }
                .disabled(model.export != nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    static func format(_ seconds: Double) -> String {
        let s = Int(max(seconds, 0).rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
