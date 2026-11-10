import EditorCore
import SwiftUI

/// Buttons above the timeline: trim to the playhead, cut or speed up the selected part, restore it.
struct TimelineToolbar: View {
    @EnvironmentObject private var model: EditorModel
    @State private var askingCustomSpeed = false
    @State private var customSpeed = "3"

    var body: some View {
        let hasSelection = model.selection != nil
        HStack(spacing: 8) {
            Button { model.trimStartToPlayhead() } label: { Label("Start here", systemImage: "arrow.right.to.line") }
                .help("Trim the start to the playhead ( [ )")
                .keyboardShortcut("[", modifiers: [])
            Button { model.trimEndToPlayhead() } label: { Label("End here", systemImage: "arrow.left.to.line") }
                .help("Trim the end to the playhead ( ] )")
                .keyboardShortcut("]", modifiers: [])
            Button("Reset trim") { model.resetTrim() }
                .disabled(model.project?.timeline.trim == nil)

            Divider().frame(height: 16)

            Button { model.cutSelection() } label: { Label("Cut", systemImage: "scissors") }
                .help("Remove the selected part (Delete)")
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(!hasSelection)
            Menu {
                ForEach(Settings.speedPresets, id: \.self) { r in
                    Button(Self.speedLabel(r)) { model.setSpeedOfSelection(r) }
                }
                Button("Custom…") { askingCustomSpeed = true }
                Divider()
                Button("Normal speed") { model.setSpeedOfSelection(1) }
            } label: { Label("Speed", systemImage: "hare") }
                .fixedSize()
                .help("Speed up the selected part")
                .disabled(!hasSelection)
            Button { model.restoreSelection() } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
                .help("Put back cut parts and normal speed in the selection")
                .disabled(!hasSelection)

            Spacer()
            Text(hasSelection ? selectionText : "Click to move the playhead · drag across to select")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .controlSize(.small)
        .labelStyle(.titleAndIcon)
        .alert("Custom speed", isPresented: $askingCustomSpeed) {
            TextField("Speed", text: $customSpeed)
            Button("Apply") {
                let r = Double(customSpeed.replacingOccurrences(of: "×", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
                if Settings.customSpeedRange.contains(r) { model.setSpeedOfSelection(r) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("How many times faster, from \(Self.speedLabel(Settings.customSpeedRange.lowerBound)) to \(Self.speedLabel(Settings.customSpeedRange.upperBound)).")
        }
    }

    private var selectionText: String {
        guard let s = model.selection else { return "" }
        return "Selected \(TransportBar.format(s.start, precise: true)) – \(TransportBar.format(s.end, precise: true))"
    }

    static func speedLabel(_ r: Double) -> String {
        r == r.rounded() ? "\(Int(r))×" : String(format: "%.1f×", r)
    }
}
