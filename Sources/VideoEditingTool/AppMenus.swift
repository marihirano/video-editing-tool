import SwiftUI

/// File menu items: open, save, export.
struct AppMenus: Commands {
    @ObservedObject var model: EditorModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { Task { await model.showOpenPanel() } }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Project") { model.save() }
                .keyboardShortcut("s")
                .disabled(model.project == nil)
            Button("Save Project As…") { model.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(model.project == nil)
        }
        CommandGroup(replacing: .importExport) {
            Button("Export MP4…") { model.startExport() }
                .keyboardShortcut("e")
                .disabled(model.project == nil || model.export != nil)
        }
    }
}
