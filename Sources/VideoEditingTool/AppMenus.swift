import AppKit
import SwiftUI

/// The menu bar: File (open, save, export), Edit (undo, split, delete, tools), View, Playback.
struct AppMenus: Commands {
    @ObservedObject var model: EditorModel
    @AppStorage("showInspector") private var showInspector = true

    private var noProject: Bool { model.project == nil }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { Task { await model.showOpenPanel() } }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Project") { model.save() }
                .keyboardShortcut("s")
                .disabled(noProject)
            Button("Save Project As…") { model.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(noProject)
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
                .disabled(noProject)
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
            Divider()
            Button(model.isCutMode ? "Put Scissors Away" : "Scissors Tool") { model.toggleCutMode() }
                .keyboardShortcut("t")
                .disabled(noProject)
            Button(model.isCropMode ? "Done Cropping" : "Crop…") { model.toggleCropMode() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(noProject)
            Button("Add Zoom at Blue Line") { model.addZoomAtEditPoint() }
                .keyboardShortcut("z", modifiers: [.command, .option])
                .disabled(noProject)
        }
        CommandGroup(replacing: .importExport) {
            Button("Export…") { model.startExport() }
                .keyboardShortcut("e")
                .disabled(noProject || model.export != nil)
        }
        CommandGroup(after: .sidebar) {
            Button(showInspector ? "Hide Side Panel" : "Show Side Panel") {
                withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() }
            }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(noProject)
        }
        CommandMenu("Playback") {
            // Space plays and pauses (handled by the play button, so typing a space in a text field still works).
            Button(model.playback.isPlaying ? "Pause  (Space)" : "Play  (Space)") { model.playback.togglePlay() }
                .disabled(noProject)
            Divider()
            Button("Go to Start") { model.goToStart() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(noProject)
            Button("Go to End") { model.goToEnd() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(noProject)
        }
    }
}
