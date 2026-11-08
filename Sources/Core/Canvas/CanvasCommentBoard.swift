import Foundation

public struct CanvasCommentStatus: Sendable, Equatable {
    public var title: String
    public var detail: String
    public var needsOwner: Bool

    init(_ title: String, _ detail: String, needsOwner: Bool = false) {
        self.title = title
        self.detail = detail
        self.needsOwner = needsOwner
    }
}

public enum CanvasCommentBoard {
    public static let alreadySentSentence =
        "That comment had already gone to the agent, so it was not changed."

    public static func marks(in document: CanvasDocument, confirmed: Set<DeliveryID>) -> [CanvasComment] {
        document.comments.filter { comment in
            guard CanvasCommentFlow.visible(comment) else { return false }
            guard comment.state == .queued else { return true }
            return comment.deliveryID.map(confirmed.contains) ?? true
        }
    }

    public static func confirmed(
        previously: Set<DeliveryID>, checked: Set<DeliveryID>, live: Set<DeliveryID>
    ) -> Set<DeliveryID> {
        previously.subtracting(checked).union(live)
    }

    public static func listed(in document: CanvasDocument) -> [CanvasComment] {
        document.comments.sorted { $0.createdAt < $1.createdAt }
    }

    public static func status(of comment: CanvasComment, wait: CanvasCommentWait?) -> CanvasCommentStatus {
        switch comment.state {
        case .queued: queued(wait)
        case .working: CanvasCommentStatus("Being handled", "The agent has this comment.")
        case .unanswered: CanvasCommentStatus("Unanswered", "The turn ended without an answer. Read it, then resend it or delete it.", needsOwner: true)
        case .resolved: CanvasCommentStatus("Resolved", "The agent dealt with this comment.")
        case .declined: CanvasCommentStatus("Declined", "The agent will not do this. Open it for the reason, or delete it.")
        }
    }

    public static func status(of comment: CanvasComment, wait: CanvasCommentWait?, provenDeliveries: Set<DeliveryID>) -> CanvasCommentStatus {
        guard CanvasCommentOrigin.unansweredCameWithFile(comment, provenDeliveries: provenDeliveries) else {
            return status(of: comment, wait: wait)
        }
        return CanvasCommentStatus("Came with the file", "This was not sent in this session. Read it, then resend it or delete it.", needsOwner: true)
    }

    public static func responseLabel(of comment: CanvasComment) -> String? {
        guard comment.response != nil else { return nil }
        switch comment.state {
        case .resolved: return "Answer"
        case .declined: return "Reason"
        case .queued, .working, .unanswered: return nil
        }
    }

    public static func canEdit(_ comment: CanvasComment) -> Bool { comment.state == .queued }

    public static func canResend(_ comment: CanvasComment) -> Bool { comment.state == .unanswered }

    public static func canSend(_ comment: CanvasComment, addedThisRun: CanvasCommentsAddedThisRun) -> Bool {
        CanvasCommentOrigin.cameWithFile(comment, addedThisRun: addedThisRun)
    }

    public static func canDelete(_ comment: CanvasComment) -> Bool { comment.state != .working }

    private static func queued(_ wait: CanvasCommentWait?) -> CanvasCommentStatus {
        switch wait {
        case .cameWithFile:
            CanvasCommentStatus("Came with the file", "This was not sent in this session. Read it, then send it or delete it.", needsOwner: true)
        case .documentHeld:
            CanvasCommentStatus("Queued", "The file changed on disk. Settle the notice on this canvas and it goes.", needsOwner: true)
        case .noChat:
            CanvasCommentStatus("Queued", "No chat to send it to. Start a chat in this workspace and it goes.", needsOwner: true)
        case .stoppedByHand:
            CanvasCommentStatus("Queued", "You stopped this chat. Send it a message and the comment goes after it.", needsOwner: true)
        case .messageHeldAfterRewind:
            CanvasCommentStatus("Queued", "The rewind is holding a message queued in this chat. Send the chat a message or delete the queued one and the comment goes.", needsOwner: true)
        case .requestHeldAfterRewind:
            CanvasCommentStatus("Queued", "The rewind is holding a request Unified Dev queued in this chat. Send the chat a message and the comment goes.", needsOwner: true)
        case .draftBeingEdited:
            CanvasCommentStatus("Queued", "Held for the message in the composer. Send it or clear it and the comment goes.", needsOwner: true)
        case .held(.question):
            CanvasCommentStatus("Queued", "Answer the agent's question in the chat and it goes.", needsOwner: true)
        case .rewindInterrupted:
            CanvasCommentStatus("Queued", "Resolve the interrupted rewind in the chat and it goes.", needsOwner: true)
        case .terminalChat:
            CanvasCommentStatus("Queued", "This chat runs in a terminal and cannot take it. Delete it and leave it again.", needsOwner: true)
        case .held(.setup): CanvasCommentStatus("Queued", "Goes as soon as setup finishes.")
        case .held(.turn): CanvasCommentStatus("Queued", "Goes when this turn ends.")
        case .savingTurn: CanvasCommentStatus("Queued", "Goes once this turn's file changes are saved.")
        case .archiving: CanvasCommentStatus("Queued", "This workspace is being archived.")
        case .messageAhead: CanvasCommentStatus("Queued", "Goes after the message queued in the chat.")
        case .commentAhead: CanvasCommentStatus("Queued", "Goes after the comment before it.")
        case .nextInLine: CanvasCommentStatus("Queued", "Next in line.")
        case .held(.none), nil: CanvasCommentStatus("Queued", "Waiting to go.")
        }
    }
}
