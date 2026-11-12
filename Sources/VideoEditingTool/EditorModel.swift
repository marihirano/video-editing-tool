import AppKit
import EditorCore
import SwiftUI

/// The app's state and actions: what's open, saving, and exporting.
@MainActor
final class EditorModel: ObservableObject {
    static let shared = EditorModel()

    @Published private(set) var project: Project? {
        didSet {
            drawer?.project = project
            playback.timeMap = timeMap   // playback only reacts if the kept parts changed
        }
    }
    @Published private(set) var sourceURL: URL?
    @Published private(set) var projectURL: URL?
    /// Length of the open recording, in seconds.
    @Published private(set) var sourceDuration: Double = 0
    /// The project as last opened or saved, to tell whether there are unsaved changes.
    @Published private var savedProject: Project?
    @Published private var history = UndoHistory<Project>()
    /// The blue line: where the mouse is over the timeline (finished-video seconds), or nil.
    @Published private(set) var hoverTime: Double?
    /// The blue line when not hovering: the last clicked spot (finished-video seconds). Split happens here.
    @Published private(set) var editTime: Double?
    /// The clip last clicked (highlighted), by its position on the timeline.
    @Published var selectedClip: Int?
    /// True while the scissors tool is out: the next click on the timeline cuts there.
    @Published private(set) var isCutMode = false
    private lazy var cutMode = CutMode { [weak self] in self?.endCutMode() }
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

    var hasUnsavedChanges: Bool { project != nil && project != savedProject }
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    /// How the timeline edits map the recording onto the finished video.
    var timeMap: TimeMap? { project.map { TimeMap(project: $0, sourceDuration: sourceDuration) } }

    /// Every edit goes through here, so each one can be undone. Quick repeats with the same
    /// `group` (a slider or handle drag) become one undo step.
    func edit(group: String? = nil, _ change: (inout Project) -> Void) {
        guard let old = project else { return }
        var p = old
        change(&p)
        guard p != old else { return }
        history.record(old, group: group)
        project = p
    }

    func undo() {
        guard let current = project, let previous = history.undo(current: current) else { return }
        project = previous
    }

    func redo() {
        guard let current = project, let next = history.redo(current: current) else { return }
        project = next
    }

    /// Changes the frame style (background, padding, corners, shadow); the preview updates at once.
    func updateStyle(_ change: (inout FrameStyle) -> Void) {
        edit(group: "style") { change(&$0.style) }
    }

    // MARK: Timeline (positions are finished-video seconds)

    var clips: [Clip] { project?.timeline.resolvedClips(sourceDuration: sourceDuration) ?? [] }

    /// Where the blue line is drawn: under the mouse, else the clicked spot.
    var blueLineTime: Double? { hoverTime ?? editTime }

    /// Mouse over the timeline: the blue line follows and the preview shows that moment.
    func hover(at t: Double?) {
        hoverTime = t
        guard let map = timeMap else { return }
        if let t { playback.skim(to: map.sourceTime(forOutput: t)) } else { playback.endSkim() }
    }

    /// Click (or drag) on the timeline: pins the blue line and moves the playhead there.
    func setEditPoint(_ t: Double) {
        guard let map = timeMap else { return }
        let t = min(max(t, 0), map.outputDuration)
        editTime = t
        playback.seek(to: map.sourceTime(forOutput: t))
    }

    /// Scissors button: takes the scissors tool out, or puts it away if it's already out.
    func toggleCutMode() { isCutMode ? endCutMode() : startCutMode() }

    func startCutMode() {
        guard project != nil else { return }
        isCutMode = true
        cutMode.start()
    }

    func endCutMode() {
        isCutMode = false
        cutMode.stop()
    }

    /// A click on the timeline with the scissors tool: splits the clip there. The tool stays out
    /// until the scissors button is clicked again.
    func cut(atOutput t: Double) {
        let d = sourceDuration
        edit { $0.timeline.split(atOutput: t, sourceDuration: d) }
        setEditPoint(t)
    }

    /// ⌘B: splits the clip under the blue line (or the playhead if no line is set).
    func splitAtEditPoint() {
        guard project != nil else { return }
        let t = blueLineTime ?? playback.outputTime
        let d = sourceDuration
        edit { $0.timeline.split(atOutput: t, sourceDuration: d) }
    }

    func deleteClip(_ i: Int) {
        let d = sourceDuration
        edit { $0.timeline.deleteClip(i, sourceDuration: d) }
        selectedClip = nil
        // Keep the blue line and playhead inside the shorter video.
        if let map = timeMap {
            if let e = editTime { editTime = min(e, map.outputDuration) }
            playback.seek(to: map.sourceTime(forOutput: min(playback.outputTime, map.outputDuration)))
        }
    }

    func setSpeed(_ rate: Double, ofClip i: Int) {
        let d = sourceDuration
        let src = editTime.flatMap { timeMap?.sourceTime(forOutput: $0) }
        edit { $0.timeline.setRate(rate, ofClip: i, sourceDuration: d) }
        // The video's clock changed; keep the blue line on the same recorded moment.
        if let src, let map = timeMap { editTime = map.outputTime(forSource: src) }
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
        guard confirmDiscardChanges() else { return }
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
        sourceDuration = source.duration
        self.project = project
        savedProject = project
        history.reset()
        hoverTime = nil; editTime = nil; selectedClip = nil
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
            savedProject = project
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            errorMessage = "Couldn't save the project. \(error.localizedDescription)"
        }
    }

    /// Before closing, quitting or opening something else: offers to save unsaved changes.
    /// Returns false if the person chose Cancel (or cancelled the save).
    func confirmDiscardChanges() -> Bool {
        guard hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(displayName)”?"
        alert.informativeText = "Your edits will be lost if you don't save them."
        alert.addButton(withTitle: projectURL == nil ? "Save…" : "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save").hasDestructiveAction = true
        switch alert.runModal() {
        case .alertFirstButtonReturn: save(); return !hasUnsavedChanges
        case .alertThirdButtonReturn: savedProject = project; return true   // so quitting next doesn't ask again
        default: return false
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
