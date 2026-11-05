import Foundation

public struct CanvasCommentsAddedThisRun: Sendable, Equatable {
    private struct Entry: Sendable, Equatable {
        let text: String
        let goesLast: Bool
    }

    private var entries: [CanvasCommentID: Entry] = [:]

    public init() {}

    public mutating func add(_ comment: CanvasComment, goesLast: Bool = false) {
        entries[comment.id] = Entry(text: comment.text, goesLast: goesLast)
    }

    public mutating func addEdited(_ comment: CanvasComment) {
        add(comment, goesLast: true)
    }

    public mutating func consume(_ id: CanvasCommentID) {
        entries[id] = nil
    }

    public mutating func spend(after outcome: CanvasCommentChangeOutcome, deleting id: CanvasCommentID) {
        if case .changed = outcome { consume(id) }
    }

    public func covers(_ comment: CanvasComment) -> Bool {
        entries[comment.id]?.text == comment.text
    }

    public func goesLast(_ comment: CanvasComment) -> Bool {
        entries[comment.id]?.goesLast == true
    }
}

public enum CanvasCommentOrigin {
    public static func cameWithFile(_ comment: CanvasComment, addedThisRun: CanvasCommentsAddedThisRun) -> Bool {
        comment.state == .queued && comment.deliveryID == nil && !addedThisRun.covers(comment)
    }
}
