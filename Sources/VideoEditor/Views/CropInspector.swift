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
        PanelScaffold {
            PanelHeader(back: { model.endCropMode() }, title: "Crop",
                        detail: "Keeping \(w) × \(h) of \(p?.source.width ?? 0) × \(p?.source.height ?? 0) pixels")
            PanelNote("Drag the corners or edges on the preview. Drag inside the box to move it.")
            HStack {
                Button("Reset") { model.resetCrop() }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(p?.crop == nil)
                Spacer()
                Button("Done") { model.endCropMode() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
        }
    }
}
