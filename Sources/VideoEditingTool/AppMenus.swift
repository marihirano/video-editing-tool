import AppKit
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
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model.undo() }
                .keyboardShortcut("z")
                .disabled(!model.canUndo)
            Button("Redo") { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.canRedo)
            Divider()
            Button("Split Clip at Blue Line") { model.splitAtEditPoint() }
                .keyboardShortcut("b")
                .disabled(model.project == nil)
            Button(model.selectedZoom != nil ? "Delete Zoom" : "Delete Clip") {
                // While typing (e.g. a custom speed), Delete just erases a character.
                if NSApp.keyWindow?.firstResponder is NSTextView {
                    NSApp.sendAction(#selector(NSText.deleteBackward(_:)), to: nil, from: nil); return
                }
                if let i = model.selectedZoom { model.deleteZoom(i) }
                else if let i = model.selectedClip { model.deleteClip(i) }
            }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(model.selectedZoom == nil && (model.selectedClip == nil || model.clips.count < 2))
        }
        CommandGroup(replacing: .importExport) {
            Button("Export MP4…") { model.startExport() }
                .keyboardShortcut("e")
                .disabled(model.project == nil || model.export != nil)
        }
    }
}
