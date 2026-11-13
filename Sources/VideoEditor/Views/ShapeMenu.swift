import EditorCore
import SwiftUI

/// The video-shape button above the preview, left of Crop: an icon, the current shape and a
/// chevron; clicking opens a menu with Widescreen 16:9, Square 1:1 and Vertical 9:16.
/// The shape also decides the export sizes. Changes are undoable (`EditorModel.setOutput`).
struct ShapeMenu: View {
    @EnvironmentObject private var model: EditorModel
    @State private var hovering = false

    private var shape: VideoShape { model.project?.output.shape ?? Settings.defaultVideoShape }

    var body: some View {
        Menu {
            Picker("Shape", selection: Binding(get: { shape }, set: { s in model.setOutput { $0.setShape(s) } })) {
                ForEach(VideoShape.allCases, id: \.self) { s in
                    Text("\(Self.name(s))  \(s.ratioLabel)").tag(s)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: Theme.s2) {
                Image(systemName: "aspectratio").font(.system(size: 14, weight: .light))
                Text(shape.ratioLabel).font(Theme.fontBody)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .light))
                    .foregroundStyle(Theme.secondaryText)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, Theme.s3)
            .frame(minHeight: 28)
            .background(RoundedRectangle(cornerRadius: Theme.radius)
                .fill(hovering ? Theme.controlFill : Color.clear))   // no fill until hovered (and while its menu is open)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .help("Video shape (also sets the export size)")
        .accessibilityLabel("Video shape")
    }

    /// "Widescreen", "Square", "Vertical".
    static func name(_ s: VideoShape) -> String {
        switch s {
        case .wide: return "Widescreen"
        case .square: return "Square"
        case .vertical: return "Vertical"
        }
    }
}
