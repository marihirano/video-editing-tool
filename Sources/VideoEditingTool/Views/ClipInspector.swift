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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { model.selectedClip = nil } label: {
                    Label("Style", systemImage: "chevron.left").font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Back to background and frame settings")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Clip \(index + 1) of \(clips.count)").font(.title3.weight(.semibold))
                    Text("\(TimelineView.lengthLabel(clip.outputDuration)) in the video · recording \(Self.time(clip.start))–\(Self.time(clip.end))")
                        .font(.callout).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Speed").font(.headline)
                    HStack(spacing: 6) {
                        ForEach([1.0] + Settings.speedPresets, id: \.self) { r in
                            speedButton(r, selected: abs(clip.rate - r) < 0.001)
                        }
                    }
                    HStack(spacing: 6) {
                        Text("Custom").font(.callout)
                        Spacer()
                        TextField("", text: $customText)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onSubmit { applyCustom() }
                        Text("×").font(.callout)
                        Button("Apply") { applyCustom() }.controlSize(.small)
                    }
                    Text("From \(TimelineView.speedLabel(Settings.customSpeedRange.lowerBound)) to \(TimelineView.speedLabel(Settings.customSpeedRange.upperBound)).")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Button(role: .destructive) { model.deleteClip(index) } label: {
                    Label("Delete clip", systemImage: "trash")
                }
                .disabled(clips.count < 2)
                .help(clips.count < 2 ? "The video needs at least one clip" : "Remove this clip from the video (Delete)")
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
        }
        .frame(width: 300)
        .background(.bar)
        .onAppear { customText = Self.number(clip.rate) }
        .onChange(of: clip.rate) { customText = Self.number(clip.rate) }
        .onChange(of: index) { customText = Self.number(clip.rate) }
    }

    private func speedButton(_ r: Double, selected: Bool) -> some View {
        Button { model.setSpeed(r, ofClip: index) } label: {
            Text(TimelineView.speedLabel(r))
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 28)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
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
