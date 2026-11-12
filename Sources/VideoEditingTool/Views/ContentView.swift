import EditorCore
import SwiftUI

/// The main window: a drop area when nothing is open, otherwise the preview and controls.
struct ContentView: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isDropTargeted = false
    @AppStorage("showInspector") private var showInspector = true

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if model.project == nil {
                    EmptyStateView(isTargeted: isDropTargeted)
                } else {
                    PreviewArea()
                    TimelineView()
                }
            }
            if model.project != nil && showInspector {
                Divider()
                Group {
                    if let i = model.selectedClip, model.clips.indices.contains(i) { ClipInspector(index: i) }
                    else { InspectorView() }
                }
                .transition(.move(edge: .trailing))
            }
        }
        .background(Color(rgba: Settings.previewSurround))
        .background(WindowCloseGuard())
        .navigationTitle(model.displayName)
        .toolbar { toolbar }
        // Selecting a clip opens the side panel if it was hidden, to show the clip's speed.
        .onChange(of: model.selectedClip) { if model.selectedClip != nil && !showInspector { withAnimation(.easeInOut(duration: 0.2)) { showInspector = true } } }
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

extension ContentView {
    /// Top bar: title in the middle; undo, redo, side-panel toggle and Export on the right.
    @ToolbarContentBuilder var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(model.displayName).font(.headline)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .help("Undo (⌘Z)").disabled(!model.canUndo)
            Button { model.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
                .help("Redo (⇧⌘Z)").disabled(!model.canRedo)
        }
        ToolbarItem(placement: .primaryAction) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() } } label: {
                Label("Side Panel", systemImage: "sidebar.right")
            }
            .help(showInspector ? "Hide the style panel" : "Show the style panel")
            .disabled(model.project == nil)
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Export MP4") { model.startExport() }
                .buttonStyle(.borderedProminent)
                .disabled(model.project == nil || model.export != nil)
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
