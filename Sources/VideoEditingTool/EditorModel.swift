import AppKit
import EditorCore
import SwiftUI

/// The app's state and actions: what's open, saving, and exporting.
@MainActor
final class EditorModel: ObservableObject {
    static let shared = EditorModel()

    @Published private(set) var project: Project? { didSet { drawer?.project = project } }
    @Published private(set) var sourceURL: URL?
    @Published private(set) var projectURL: URL?
    /// True once the style has been changed since opening or saving. (Undo comes in M3.)
    @Published private(set) var hasUnsavedChanges = false
    @Published var errorMessage: String?
    @Published var export: ExportState?

    let playback: PlaybackController
    let drawer: PreviewDrawer?
    private var exporter: Exporter?

    enum ExportState: Equatable {
        case running(progress: Double)
        case finished(URL)
        case failed(String)
    }

    init() {
        let playback = PlaybackController()
        self.playback = playback
        drawer = MetalContext.shared.map { PreviewDrawer(renderer: FrameRenderer(context: $0), playback: playback) }
        if drawer == nil { errorMessage = "This Mac's graphics chip couldn't be used for the preview." }
    }

    /// Changes the frame style (background, padding, corners, shadow); the preview updates at once.
    func updateStyle(_ change: (inout FrameStyle) -> Void) {
        guard var p = project else { return }
        change(&p.style)
        guard p != project else { return }
        project = p
        hasUnsavedChanges = true
    }

    /// Name shown in the window title.
    var displayName: String {
        if let projectURL { return projectURL.deletingPathExtension().lastPathComponent }
        return sourceURL?.lastPathComponent ?? "Video Editing Tool"
    }

    // MARK: Opening

    func showOpenPanel() async {
        if let url = FilePanels.chooseFileToOpen() { await open(url) }
    }

    /// Opens a project package or imports a video, depending on what it is.
    func open(_ url: URL) async {
        FilePanels.isProject(url) ? await openProject(url) : await importVideo(url)
    }

    func importVideo(_ url: URL) async {
        do {
            let info = try await VideoInfo.load(url)
            show(Project(source: info.sourceVideo), source: info, projectURL: nil)
        } catch {
            errorMessage = "Couldn't open “\(url.lastPathComponent)”. \(error.localizedDescription)"
        }
    }

    func openProject(_ url: URL) async {
        do {
            let (project, source) = try ProjectStore.load(from: url)
            let info = try await VideoInfo.load(source)
            show(project, source: info, projectURL: url)
        } catch {
            errorMessage = "Couldn't open the project “\(url.lastPathComponent)”. \(error.localizedDescription)"
        }
    }

    private func show(_ project: Project, source: VideoInfo, projectURL: URL?) {
        playback.pause()
        self.project = project
        hasUnsavedChanges = false
        self.sourceURL = source.url
        self.projectURL = projectURL
        playback.load(source)
        if projectURL == nil { NSDocumentController.shared.noteNewRecentDocumentURL(source.url) }
        else { NSDocumentController.shared.noteNewRecentDocumentURL(projectURL!) }
    }

    // MARK: Saving

    func save() {
        if let projectURL { write(to: projectURL) } else { saveAs() }
    }

    func saveAs() {
        guard let sourceURL else { return }
        let name = sourceURL.deletingPathExtension().lastPathComponent + "." + Settings.projectExtension
        if let url = FilePanels.chooseProjectLocation(suggestedName: name) { write(to: url) }
    }

    private func write(to url: URL) {
        guard let project, let sourceURL else { return }
        do {
            try ProjectStore.save(project, sourceURL: sourceURL, to: url)
            projectURL = url
            hasUnsavedChanges = false
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            errorMessage = "Couldn't save the project. \(error.localizedDescription)"
        }
    }

    // MARK: Exporting

    func startExport() {
        guard let project, let sourceURL, export == nil else { return }
        let name = displayName.replacingOccurrences(of: "." + sourceURL.pathExtension, with: "") + ".mp4"
        guard let outURL = FilePanels.chooseExportLocation(suggestedName: name) else { return }
        playback.pause()
        let exporter = Exporter()
        self.exporter = exporter
        export = .running(progress: 0)
        Task {
            do {
                try await exporter.export(project: project, sourceURL: sourceURL, to: outURL) { [weak self] p in
                    MainActor.assumeIsolated {
                        if case .running = self?.export { self?.export = .running(progress: p) }
                    }
                }
                export = .finished(outURL)
            } catch is CancellationError {
                export = nil
            } catch {
                export = .failed(error.localizedDescription)
            }
            self.exporter = nil
        }
    }

    func cancelExport() { exporter?.cancel() }

    func dismissExport() { export = nil }
}
