import EditorCore
import SwiftUI

/// The side panel while a clip is selected: its speed, and delete.
/// "‹ Style" at the top goes back to the background and frame settings.
struct ClipInspector: View {
    @EnvironmentObject private var model: EditorModel
    let index: Int
    @State private var customText = ""

    var body: some View {
        let clips = model.clips
        let clip = clips.indices.contains(index) ? clips[index] : Clip(start: 0, end: 0)
        PanelScaffold {
            PanelHeader(back: { model.selectedClip = nil }, title: "Clip \(index + 1) of \(clips.count)",
                        detail: "\(TimelineView.lengthLabel(clip.outputDuration)) in the video · recording \(Self.time(clip.start))–\(Self.time(clip.end))")

            PanelSection("Speed") {
                ChoiceButtons(choices: [1.0] + Settings.speedPresets, isSelected: { abs(clip.rate - $0) < 0.001 },
                              label: { TimelineView.speedLabel($0) }) { model.setSpeed($0, ofClip: index) }
                HStack(spacing: Theme.s2) {
                    Text("Custom").font(.callout)
                    Spacer()
                    TextField("", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onSubmit { applyCustom() }
                    Text("×").font(.callout)
                    Button("Apply") { applyCustom() }.buttonStyle(QuietButtonStyle())
                }
                PanelNote("From \(TimelineView.speedLabel(Settings.customSpeedRange.lowerBound)) to \(TimelineView.speedLabel(Settings.customSpeedRange.upperBound)).")
            }

            Button(role: .destructive) { model.deleteClip(index) } label: {
                Label("Delete clip", systemImage: "trash")
            }
            .buttonStyle(QuietButtonStyle(destructive: true))
            .disabled(clips.count < 2)
            .help(clips.count < 2 ? "The video needs at least one clip" : "Remove this clip from the video (Delete)")
        }
        .onAppear { customText = Self.number(clip.rate) }
        .onChange(of: clip.rate) { customText = Self.number(clip.rate) }
        .onChange(of: index) { customText = Self.number(clip.rate) }
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
