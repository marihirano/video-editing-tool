import EditorCore
import SwiftUI

/// The side panel while the crop handles are out.
struct CropInspector: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        let p = model.project
        let f = model.cropFraction
        let w = Int((f.width * Double(p?.source.width ?? 0)).rounded())
        let h = Int((f.height * Double(p?.source.height ?? 0)).rounded())
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { model.endCropMode() } label: {
                    Label("Style", systemImage: "chevron.left").font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Back to background and frame settings")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Crop").font(.title3.weight(.semibold))
                    Text("Keeping \(w) × \(h) of \(p?.source.width ?? 0) × \(p?.source.height ?? 0) pixels")
                        .font(.callout).foregroundStyle(.secondary)
                }

                Text("Drag the corners or edges on the preview. Drag inside the box to move it.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button("Reset") { model.resetCrop() }
                        .disabled(p?.crop == nil)
                    Spacer()
                    Button("Done") { model.endCropMode() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
        }
        .frame(width: 300)
        .background(.bar)
    }
}
