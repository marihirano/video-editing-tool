import AppKit
import EditorCore
import UniformTypeIdentifiers

/// The standard macOS open and save dialogs, set up for this app's files.
@MainActor
enum FilePanels {
    static var projectType: UTType {
        UTType(Settings.projectTypeIdentifier)
            ?? UTType(filenameExtension: Settings.projectExtension, conformingTo: .package)
            ?? .package
    }

    static func isProject(_ url: URL) -> Bool { url.pathExtension == Settings.projectExtension }

    static func chooseFileToOpen() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, projectType]
        panel.message = "Choose a screen recording or a saved project"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseProjectLocation(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [projectType]
        panel.nameFieldStringValue = suggestedName
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseExportLocation(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = suggestedName
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseBackgroundImage() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = "Choose a picture for the background"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
