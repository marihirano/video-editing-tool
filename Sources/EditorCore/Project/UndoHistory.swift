import Foundation

/// Remembers earlier versions of the project for Undo and Redo.
///
/// The project is a small value, so each step simply stores the whole previous version.
/// A run of quick changes with the same `group` (one slider drag, one handle drag) is one step.
public struct UndoHistory<Value: Equatable>: Sendable where Value: Sendable {
    private var undoStack: [Value] = []
    private var redoStack: [Value] = []
    private var lastGroup: String?
    private var lastChange: Date = .distantPast

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call before replacing `old` with a new version.
    public mutating func record(_ old: Value, group: String? = nil, now: Date = Date()) {
        let continuing = group != nil && group == lastGroup
            && now.timeIntervalSince(lastChange) < Settings.undoCoalesceSeconds
        if !continuing {
            undoStack.append(old)
            if undoStack.count > Settings.undoLimit { undoStack.removeFirst() }
        }
        redoStack.removeAll()
        lastGroup = group
        lastChange = now
    }

    public mutating func undo(current: Value) -> Value? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        lastGroup = nil
        return previous
    }

    public mutating func redo(current: Value) -> Value? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        lastGroup = nil
        return next
    }

    public mutating func reset() { self = UndoHistory() }
}
