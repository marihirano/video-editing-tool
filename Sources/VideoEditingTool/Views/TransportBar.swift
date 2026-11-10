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

            // Time in the finished video (after trims, cuts and speed-ups).
            Text("\(Self.format(playback.outputTime)) / \(Self.format(playback.outputDuration))")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .help("Undo (⌘Z)").disabled(!model.canUndo)
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .help("Redo (⇧⌘Z)").disabled(!model.canRedo)

            Button("Export MP4…") { model.startExport() }
                .disabled(model.export != nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    static func format(_ seconds: Double, precise: Bool = false) -> String {
        let s = Int(max(seconds, 0).rounded(.down))
        if precise { return String(format: "%d:%02d.%d", s / 60, s % 60, Int((max(seconds, 0) * 10).rounded(.down)) % 10) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
