import EditorCore
import SwiftUI

/// The row under the preview. Left: the Cut, Crop and Zoom tools. Centre: play/pause and the
/// time in the finished video. The right is left empty so play stays centred.
struct TransportBar: View {
    @EnvironmentObject private var model: EditorModel
    @EnvironmentObject private var playback: PlaybackController

    var body: some View {
        ZStack {
            HStack(spacing: Theme.s2) {
                ToolButton(title: "Cut", systemImage: "scissors", isOn: model.isCutMode,
                           help: model.isCutMode ? "Click the timeline to cut; click Cut again (or Esc) to stop" : "Cut: turn on the scissors, then click the timeline where you want to cut") {
                    model.toggleCutMode()
                }
                ToolButton(title: "Zoom", systemImage: "plus.magnifyingglass",
                           help: "Add a zoom at the blue line (⌥⌘Z)") {
                    model.addZoomAtEditPoint()
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: Theme.s3) {
                Button { playback.togglePlay() } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.playFill)
                        .offset(x: playback.isPlaying ? 0 : 1)   // a play triangle looks centred a touch right
                        .frame(width: Theme.playButtonSize, height: Theme.playButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .help(playback.isPlaying ? "Pause (Space)" : "Play (Space)")

                (Text(Self.tenths(playback.outputTime)).foregroundStyle(.primary)
                 + Text(" / \(Self.tenths(playback.outputDuration))").foregroundStyle(Theme.secondaryText))
                    .font(Theme.fontBody.monospacedDigit())
            }
        }
        .frame(height: Theme.transportHeight)
    }

    /// "0:05": minutes and whole seconds (the ruler's labels).
    static func format(_ seconds: Double) -> String {
        let s = Int(max(seconds, 0).rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "0:19.4": minutes, seconds and tenths.
    static func tenths(_ seconds: Double) -> String {
        let t = Int((max(seconds, 0) * 10).rounded())
        return String(format: "%d:%02d.%d", t / 600, (t / 10) % 60, t % 10)
    }
}
