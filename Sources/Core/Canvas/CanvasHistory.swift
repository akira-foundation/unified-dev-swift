import Foundation

public struct CanvasHistory: Sendable, Equatable {
    public static let limit = 100

    private var undoStack: [CanvasDocument] = []
    private var redoStack: [CanvasDocument] = []
    public private(set) var commentLinks = CanvasCommentLinks()

    public init() {}

    public var undoDepth: Int { undoStack.count }

    var heldDocuments: [CanvasDocument] { undoStack + redoStack }

    public mutating func record(before: CanvasDocument) {
        commentLinks.note(before)
        undoStack.append(before)
        if undoStack.count > Self.limit { undoStack.removeFirst(undoStack.count - Self.limit) }
        redoStack.removeAll()
    }

    public mutating func undo(current: CanvasDocument) -> CanvasDocument? {
        guard let snapshot = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return Self.restoring(snapshot, over: current)
    }

    public mutating func redo(current: CanvasDocument) -> CanvasDocument? {
        guard let snapshot = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return Self.restoring(snapshot, over: current)
    }

    private static func restoring(_ snapshot: CanvasDocument, over current: CanvasDocument) -> CanvasDocument {
        var restored = current
        restored.frames = bumped(snapshot.frames, over: current.frames)
        restored.elements = bumped(snapshot.elements, over: current.elements)
        return restored
    }

    private static func bumped<Item: CanvasRevisioned>(_ items: [Item], over current: [Item]) -> [Item] {
        let live = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return items.map { item in
            let existing = live[item.id]
            if existing == item { return item }
            var changed = item
            changed.revision = max(item.revision, existing?.revision ?? item.revision) + 1
            return changed
        }
    }
}

private protocol CanvasRevisioned: Identifiable, Equatable where ID: Hashable {
    var revision: Int { get set }
}

extension CanvasFrame: CanvasRevisioned {}
extension CanvasElement: CanvasRevisioned {}
