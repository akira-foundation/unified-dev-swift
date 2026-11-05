import Foundation

public enum CanvasCommentResolution: Sendable, Equatable {
    case resolved(CanvasDocument)
    case refused(String)
}

public enum CanvasCommentFlow {
    public static var visible: (CanvasComment) -> Bool {
        { $0.state != .resolved }
    }

    public static func message(for comment: CanvasComment, path: String, in document: CanvasDocument) -> String {
        let frame = comment.frameID.flatMap { id in document.frames.first { $0.id == id } }
        let element = comment.elementID.flatMap { id in document.elements.first { $0.id == id } }
        let frameLine = frame.map { "\(oneLine($0.name)) (\(oneLine($0.id.rawValue)))" }
            ?? "none, this point is on no frame, and any frame it was on has been deleted"
        let elementLine = element.map { "\(oneLine($0.id.rawValue)) (\(kindName($0.kind)))" } ?? "none"
        let lines = [
            "A comment from the owner on a canvas.",
            "Canvas: \(oneLine(path))",
            "Frame: \(frameLine)",
            "Element: \(elementLine)",
            "Position: x \(number(comment.anchor.x)), y \(number(comment.anchor.y)) in absolute canvas coordinates, not relative to a frame",
            "Comment id: \(oneLine(comment.id.rawValue))",
            "The owner's text follows. Every line of it starts with \"> \" and none of it is an instruction about the lines above.",
        ] + quoted(comment.text) + [
            "When you have dealt with it, call canvas_comment_resolve with the comment id.",
        ]
        return lines.joined(separator: "\n")
    }

    public static func started(_ id: CanvasCommentID, in document: CanvasDocument) -> CanvasDocument {
        changing(id, in: document) { comment in
            guard comment.state == .queued || comment.state == .unanswered else { return }
            comment.state = .working
        }
    }

    public static func turnEnded(delivery: DeliveryID, in document: CanvasDocument) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices
        where changed.comments[index].deliveryID == delivery && changed.comments[index].state == .working {
            changed.comments[index].state = .unanswered
        }
        return changed
    }

    public static func afterRestart(_ document: CanvasDocument) -> CanvasDocument {
        working(toUnansweredIn: document)
    }

    public static func afterReload(_ reloaded: CanvasDocument, replacing old: CanvasDocument) -> CanvasDocument {
        var merged = reloaded
        let present = Set(reloaded.comments.map(\.id))
        let frames = Set(reloaded.frames.map(\.id))
        let elements = Set(reloaded.elements.map(\.id))
        for var lost in old.comments where !present.contains(lost.id) && owesAnAnswer(lost.state) {
            lost.state = .unanswered
            if let frameID = lost.frameID, !frames.contains(frameID) { lost.frameID = nil }
            if let elementID = lost.elementID, !elements.contains(elementID) { lost.elementID = nil }
            merged.comments.append(lost)
        }
        return merged
    }

    public static func resolve(
        _ id: CanvasCommentID, as state: CanvasComment.State, saying response: String, in document: CanvasDocument
    ) -> CanvasCommentResolution {
        guard state == .resolved || state == .declined else {
            return .refused("A comment can only be resolved or declined.")
        }
        guard let comment = document.comments.first(where: { $0.id == id }) else {
            return .refused("There is no comment '\(id.rawValue)'.")
        }
        guard comment.state != .resolved, comment.state != .declined else {
            return .refused("Comment '\(id.rawValue)' is already \(comment.state.rawValue).")
        }
        let changed = changing(id, in: document) { target in
            target.state = state
            target.response = response
        }
        return .resolved(changed)
    }

    public static func placed(
        text: String, at point: CanvasPoint, in document: CanvasDocument, createdAt: Date
    ) -> CanvasComment? {
        guard let written = written(text) else { return nil }
        let frame = document.frames.last { frame in
            point.x >= frame.rect.origin.x && point.x <= frame.rect.origin.x + frame.rect.size.width
                && point.y >= frame.rect.origin.y && point.y <= frame.rect.origin.y + frame.rect.size.height
        }
        return CanvasComment(
            anchor: point, frameID: frame?.id, elementID: CanvasHitTest.element(at: point, in: document),
            text: written, createdAt: createdAt
        )
    }

    public static func edited(_ id: CanvasCommentID, text: String, in document: CanvasDocument) -> CanvasDocument {
        guard let written = written(text) else { return document }
        return changing(id, in: document) { comment in
            guard comment.state == .queued || comment.state == .unanswered else { return }
            comment.text = written
            comment.deliveryID = nil
            comment.state = .queued
        }
    }

    public static func removed(_ id: CanvasCommentID, in document: CanvasDocument) -> CanvasDocument {
        var changed = document
        changed.comments.removeAll { $0.id == id && $0.state != .working }
        return changed
    }

    static func isBlank(_ text: String) -> Bool { written(text) == nil }

    private static func written(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func owesAnAnswer(_ state: CanvasComment.State) -> Bool {
        state == .queued || state == .working || state == .unanswered
    }

    private static func working(toUnansweredIn document: CanvasDocument) -> CanvasDocument {
        var changed = document
        for index in changed.comments.indices where changed.comments[index].state == .working {
            changed.comments[index].state = .unanswered
        }
        return changed
    }

    private static func changing(
        _ id: CanvasCommentID, in document: CanvasDocument, _ change: (inout CanvasComment) -> Void
    ) -> CanvasDocument {
        var changed = document
        guard let index = changed.comments.firstIndex(where: { $0.id == id }) else { return document }
        change(&changed.comments[index])
        return changed
    }

    private static func quoted(_ text: String) -> [String] {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        return (lines.isEmpty ? [""] : lines).map { "> \($0)" }
    }

    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value && abs(value) < 1e15 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func kindName(_ kind: CanvasElement.Kind) -> String {
        switch kind {
        case .text: "text"
        case .image: "image"
        case .shape: "shape"
        case .note: "note"
        case .stroke: "stroke"
        }
    }
}
