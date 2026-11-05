import Foundation

public enum CanvasCommentCancelAnswer: Sendable, Equatable {
    case removed
    case rowFinished
    case rowInFlight
    case failed(String)

    public static func afterRefusal(row: Delivery?) -> CanvasCommentCancelAnswer {
        guard let row else { return .removed }
        return row.state == .accepted ? .rowFinished : .rowInFlight
    }
}

public enum CanvasCommentChangeOutcome: Sendable, Equatable {
    case changed(CanvasDocument)
    case unchanged
    case alreadyLeft
    case notEditable
    case couldNotCheck(String)

    public var sentence: String? {
        switch self {
        case .changed, .unchanged: nil
        case .alreadyLeft: CanvasCommentBoard.alreadySentSentence
        case .notEditable: "That comment can no longer be changed, so nothing happened."
        case .couldNotCheck(let reason): "Could not check that comment in the queue, so it was not changed. \(reason)"
        }
    }
}

public enum CanvasCommentChangeStart: Sendable, Equatable {
    case finished(CanvasCommentChangeOutcome)
    case cancel(DeliveryID?)
}

public enum CanvasCommentEdit {
    public static func beginEdit(_ id: CanvasCommentID, text: String, in document: CanvasDocument) -> CanvasCommentChangeStart {
        guard let comment = comment(id, in: document), !CanvasCommentFlow.isBlank(text) else { return .finished(.notEditable) }
        guard CanvasCommentBoard.canEdit(comment) else { return .finished(.alreadyLeft) }
        guard shownTrimmed(comment.text) != shownTrimmed(text) else { return .finished(.unchanged) }
        return .cancel(comment.deliveryID)
    }

    public static func concludeEdit(
        _ id: CanvasCommentID, text: String, answer: CanvasCommentCancelAnswer, in document: CanvasDocument
    ) -> CanvasCommentChangeOutcome {
        switch answer {
        case .failed(let reason):
            return .couldNotCheck(reason)
        case .rowFinished, .rowInFlight:
            return .alreadyLeft
        case .removed:
            let edited = CanvasCommentFlow.edited(id, text: text, in: document)
            return edited == document ? .alreadyLeft : .changed(edited)
        }
    }

    public static func beginResend(
        _ id: CanvasCommentID, showing text: String, in document: CanvasDocument
    ) -> CanvasCommentChangeStart {
        guard let comment = comment(id, in: document), comment.text == text,
              CanvasCommentBoard.canResend(comment) else { return .finished(.notEditable) }
        return .cancel(comment.deliveryID)
    }

    public static func concludeResend(
        _ id: CanvasCommentID, showing text: String, answer: CanvasCommentCancelAnswer, in document: CanvasDocument
    ) -> CanvasCommentChangeOutcome {
        switch answer {
        case .failed(let reason):
            return .couldNotCheck(reason)
        case .rowInFlight:
            return .alreadyLeft
        case .removed, .rowFinished:
            guard let index = document.comments.firstIndex(where: { $0.id == id }),
                  document.comments[index].text == text,
                  CanvasCommentBoard.canResend(document.comments[index]) else { return .notEditable }
            var changed = document
            changed.comments[index].deliveryID = nil
            return .changed(changed)
        }
    }

    public static func beginDelete(_ id: CanvasCommentID, in document: CanvasDocument) -> CanvasCommentChangeStart {
        guard let comment = comment(id, in: document) else { return .finished(.notEditable) }
        guard CanvasCommentBoard.canDelete(comment) else { return .finished(.alreadyLeft) }
        return .cancel(comment.state == .queued ? comment.deliveryID : nil)
    }

    public static func concludeDelete(
        _ id: CanvasCommentID, answer: CanvasCommentCancelAnswer, in document: CanvasDocument
    ) -> CanvasCommentChangeOutcome {
        switch answer {
        case .failed(let reason):
            return .couldNotCheck(reason)
        case .rowFinished, .rowInFlight:
            return .alreadyLeft
        case .removed:
            let removed = CanvasCommentFlow.removed(id, in: document)
            return removed == document ? .alreadyLeft : .changed(removed)
        }
    }

    private static func shownTrimmed(_ text: String) -> String {
        CanvasCommentFlow.shown(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func comment(_ id: CanvasCommentID, in document: CanvasDocument) -> CanvasComment? {
        document.comments.first { $0.id == id }
    }
}
