import EditorCore
import SwiftUI

/// The main window: a drop area when nothing is open, otherwise the preview and controls.
struct ContentView: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if model.project == nil {
                    EmptyStateView(isTargeted: isDropTargeted)
                } else {
                    PreviewArea()
                    TransportBar()
                }
            }
            if model.project != nil {
                Divider()
                InspectorView()
            }
        }
        .background(Color(rgba: Settings.previewSurround))
        .navigationTitle(model.displayName)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { await model.open(url) }
            return true
        } isTargeted: { isDropTargeted = $0 }
        .sheet(isPresented: Binding(get: { model.export != nil }, set: { if !$0 { model.dismissExport() } })) {
            ExportSheet()
        }
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil },
                                                            set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

/// The preview, kept at the output's shape (16:9 for 1080p) and centred in the window.
struct PreviewArea: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        let output = model.project?.output ?? OutputSettings()
        Group {
            if let drawer = model.drawer {
                PreviewView(drawer: drawer)
                    .aspectRatio(CGFloat(output.width) / CGFloat(output.height), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("Preview unavailable").foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    init(rgba c: RGBAColor) { self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }
}
