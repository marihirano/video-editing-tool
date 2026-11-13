import EditorCore
import SwiftUI

/// The side panel while a clip is selected: its speed, and delete.
/// "‹ Style" at the top goes back to the background and frame settings.
struct ClipInspector: View {
    @EnvironmentObject private var model: EditorModel
    let index: Int
    @State private var customText = ""
    /// True after clicking Custom: shows the number field (it also shows whenever the speed isn't a preset).
    @State private var customOpen = false
    @FocusState private var customFocused: Bool

    /// The speed choices: 1×, the presets, and "Custom" (lit when the speed is none of those).
    private enum SpeedChoice: Hashable {
        case preset(Double), custom
        static var all: [SpeedChoice] { ([1.0] + Settings.speedPresets).map { .preset($0) } + [.custom] }
        var label: String {
            switch self {
            case .preset(let r): return TimelineView.speedLabel(r)
            case .custom: return "Custom"
            }
        }
        func isSelected(rate: Double, customOpen: Bool) -> Bool {
            switch self {
            case .preset(let r): return !customOpen && abs(rate - r) < 0.001
            case .custom: return customOpen || !([1.0] + Settings.speedPresets).contains { abs(rate - $0) < 0.001 }
            }
        }
    }

    var body: some View {
        let clips = model.clips
        let clip = clips.indices.contains(index) ? clips[index] : Clip(start: 0, end: 0)
        PanelScaffold {
            PanelHeader(back: { model.selectedClip = nil }, title: "Clip \(index + 1) of \(clips.count)")

            PanelSection("Speed") {
                ChoiceButtons(choices: SpeedChoice.all, isSelected: { $0.isSelected(rate: clip.rate, customOpen: customOpen) },
                              label: { $0.label }) { choice in
                    switch choice {
                    case .preset(let r): customOpen = false; model.setSpeed(r, ofClip: index)
                    case .custom: customOpen = true; DispatchQueue.main.async { customFocused = true }   // the field appears first
                    }
                }
                if SpeedChoice.custom.isSelected(rate: clip.rate, customOpen: customOpen) {
                    HStack(spacing: Theme.s2) {
                        Text("Custom").font(Theme.fontCallout)
                        Spacer()
                        NumberField(text: $customText, suffix: "×", focused: $customFocused) { applyCustom() }
                        Button("Apply") { applyCustom() }.buttonStyle(QuietButtonStyle())
                    }
                }
            }
        } footer: {
            Button(role: .destructive) { model.deleteClip(index) } label: {
                HStack(spacing: Theme.s1 + 2) {
                    Image(systemName: "trash").font(.system(size: 14, weight: .light))
                    Text("Delete clip")
                }
            }
            .buttonStyle(QuietButtonStyle(fullWidth: true))   // white text and icon (Mari, 2026-11-13)
            .disabled(clips.count < 2)
            .help(clips.count < 2 ? "The video needs at least one clip" : "Remove this clip from the video (Delete)")
        }
        .onAppear { customText = Self.number(clip.rate) }
        .onChange(of: clip.rate) { customText = Self.number(clip.rate) }
        .onChange(of: index) { customOpen = false; customText = Self.number(clip.rate) }
    }

    private func applyCustom() {
        let r = Double(customText.replacingOccurrences(of: "×", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
        if r == 1 || Settings.customSpeedRange.contains(r) { model.setSpeed(r, ofClip: index) }
        else { customText = Self.number(model.clips.indices.contains(index) ? model.clips[index].rate : 1) }
    }

    /// "1:05.3": minutes, seconds and tenths.
    private static func time(_ t: Double) -> String {
        let tenths = Int((max(t, 0) * 10).rounded())
        return String(format: "%d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
    }

    private static func number(_ r: Double) -> String {
        r == r.rounded() ? "\(Int(r))" : String(format: "%.1f", r)
    }
}
