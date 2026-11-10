import AppKit
import SwiftUI

/// Asks to save unsaved edits when the window's close button is clicked, before the window goes.
/// SwiftUI owns the window's delegate, so this sits in front of it and passes everything else through.
struct WindowCloseGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
    }

    func makeCoordinator() -> Proxy { Proxy() }

    final class Proxy: NSObject, NSWindowDelegate {
        private weak var original: NSWindowDelegate?
        private weak var window: NSWindow?

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            self.window = window
            original = window.delegate
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard MainActor.assumeIsolated({ EditorModel.shared.confirmDiscardChanges() }) else { return false }
            return original?.windowShouldClose?(sender) ?? true
        }

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            original?.responds(to: aSelector) == true ? original : super.forwardingTarget(for: aSelector)
        }
    }
}
