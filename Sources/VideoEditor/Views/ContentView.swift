import EditorCore
import SwiftUI

/// The main window: a drop area when nothing is open. Otherwise, on one background colour: the preview
/// with its controls underneath, the side panel floating beside them (rounded, scrolls on its own),
/// and the timeline underneath across the whole width of the window.
struct ContentView: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isDropTargeted = false
    @AppStorage("showInspector") private var showInspector = true

    var body: some View {
        let panelShown = model.project != nil && showInspector
        VStack(spacing: 0) {
            if model.project == nil {
                EmptyStateView(isTargeted: isDropTargeted)
            } else {
                HStack(alignment: .top, spacing: Theme.panelPadding) {
                    PreviewArea()
                    if panelShown {
                        Group {
                            if model.isCropMode { CropInspector() }
                            else if let i = model.selectedZoom, model.zooms.indices.contains(i) { ZoomInspector(index: i) }
                            else if let i = model.selectedClip, model.clips.indices.contains(i) { ClipInspector(index: i) }
                            else { InspectorView() }
                        }
                        .frame(maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusPanel).fill(Theme.panelFill))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusPanel))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding([.horizontal, .top], Theme.panelPadding)
                TimelineView()
            }
        }
        .background(Color(rgba: Settings.previewSurround))
        .background(WindowCloseGuard())
        .navigationTitle(model.displayName)
        .toolbar { toolbar }
        // The top bar (title and buttons) uses the same colour as the rest of the window.
        .toolbarBackground(Color(rgba: Settings.previewSurround), for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        // Selecting a clip or zoom (or cropping) opens the side panel if it was hidden, to show its settings.
        .onChange(of: model.selectedClip) { if model.selectedClip != nil { revealInspector() } }
        .onChange(of: model.selectedZoom) { if model.selectedZoom != nil { revealInspector() } }
        .onChange(of: model.isCropMode) { if model.isCropMode { revealInspector() } }
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
    private func revealInspector() {
        if !showInspector { withAnimation(.easeInOut(duration: 0.2)) { showInspector = true } }
    }

    /// Top bar: title in the middle; undo, redo, side-panel toggle and Export on the right.
    /// No glass pills behind the title or the icon buttons; Export is a plain blue button with the app's usual corners.
    @ToolbarContentBuilder var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(model.displayName).font(.headline)
        }
        .withoutGlass()
        ToolbarItem(placement: .primaryAction) {
            Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .help("Undo (⌘Z)").disabled(!model.canUndo)
        }
        .withoutGlass()
        ToolbarItem(placement: .primaryAction) {
            Button { model.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
                .help("Redo (⇧⌘Z)").disabled(!model.canRedo)
        }
        .withoutGlass()
        ToolbarItem(placement: .primaryAction) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() } } label: {
                Label("Side Panel", systemImage: "sidebar.right")
            }
            .help(showInspector ? "Hide the style panel" : "Show the style panel")
            .disabled(model.project == nil)
        }
        .withoutGlass()
        ToolbarItem(placement: .primaryAction) {
            Button("Export") { model.startExport() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.project == nil || model.export != nil)
                .padding(.trailing, Theme.s1)   // keeps Export (and the buttons beside it) a little off the window's right edge
        }
        .withoutGlass()
    }
}

private extension ToolbarContent {
    /// On macOS 26 and later, removes the shared glass background the system draws behind toolbar items.
    @ToolbarContentBuilder func withoutGlass() -> some ToolbarContent {
        if #available(macOS 26, *) { self.sharedBackgroundVisibility(.hidden) } else { self }
    }
}

/// The preview, kept at the output's shape (16:9 for 1080p), with the tools / play / time row right
/// under it. The row is exactly as wide as the preview, so the tools line up with its left edge.
struct PreviewArea: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        let output = model.project?.output ?? OutputSettings()
        let aspect = CGFloat(output.width) / CGFloat(output.height)
        GeometryReader { geo in
            let spare = Theme.playButtonSize + Theme.s3
            let w = min(geo.size.width, max(geo.size.height - spare, 1) * aspect)
            VStack(spacing: Theme.s3) {
                Group {
                    if let drawer = model.drawer {
                        PreviewView(drawer: drawer)
                            .overlay(PreviewOverlay())
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    } else {
                        Text("Preview unavailable").foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(width: w, height: w / aspect)
                TransportBar().frame(width: w)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

extension Color {
    init(rgba c: RGBAColor) { self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }
}
