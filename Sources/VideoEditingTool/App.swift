import AppKit
import SwiftUI

@main
struct VideoEditingToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel.shared

    var body: some Scene {
        Window("Video Editing Tool", id: "editor") {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.playback)
                .frame(minWidth: 720, minHeight: 480)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1200, height: 780)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { AppMenus(model: model) }
    }
}

/// Opens files handed over by Finder (double-clicked projects, videos dropped on the Dock icon).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in DebugSnapshot.runIfRequested() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in await EditorModel.shared.open(url) }
    }

    /// Quitting with unsaved edits asks first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated { EditorModel.shared.confirmDiscardChanges() } ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
