import AppKit

/// The scissors tool: after the scissors button is clicked, the pointer becomes a pair of scissors
/// while it's over the timeline (a regular arrow anywhere else), and every click on the timeline cuts there. Clicking the scissors button again (or Esc)
/// puts the tool away.
@MainActor
final class CutMode {
    private var monitor: Any?
    /// True while the mouse is over the timeline tracks.
    private var overTimeline = false
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }

    static let cursor: NSCursor = {
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let symbol = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Cut")!.withSymbolConfiguration(config)!
        let size = NSSize(width: symbol.size.width + 4, height: symbol.size.height + 4)
        // White scissors with a dark outline, so they show on any background.
        let image = NSImage(size: size, flipped: false) { rect in
            func draw(_ color: NSColor, dx: CGFloat, dy: CGFloat) {
                let tinted = NSImage(size: symbol.size, flipped: false) { r in
                    symbol.draw(in: r); color.set(); r.fill(using: .sourceAtop); return true
                }
                tinted.draw(in: NSRect(x: 2 + dx, y: 2 + dy, width: symbol.size.width, height: symbol.size.height))
            }
            for (dx, dy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1)] { draw(.black, dx: dx, dy: dy) }
            draw(.white, dx: 0, dy: 0)
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
    }()

    func start() {
        stop()
        NSApp.keyWindow?.acceptsMouseMovedEvents = true
        if overTimeline { Self.cursor.set() }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp, .keyDown, .cursorUpdate]) { [weak self] event in
            guard let self else { return event }
            switch event.type {
            case .keyDown where event.keyCode == 53:   // Esc
                self.onCancel(); return nil
            default:
                // Other views reset the pointer as it moves; put the scissors back while over the timeline.
                DispatchQueue.main.async { if self.monitor != nil && self.overTimeline { Self.cursor.set() } }
            }
            return event
        }
    }

    /// Called as the mouse enters or leaves the timeline.
    func setOverTimeline(_ over: Bool) {
        guard over != overTimeline else { return }
        overTimeline = over
        guard monitor != nil else { return }
        (over ? Self.cursor : NSCursor.arrow).set()
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if monitor != nil { NSCursor.arrow.set() }
        monitor = nil
    }
}
