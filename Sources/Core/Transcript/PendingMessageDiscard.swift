import Foundation

public enum PendingMessageDiscard {
    public static func canDiscard(_ delivery: Delivery) -> Bool { delivery.isPending }

    public enum Recovery: Equatable, Sendable {
        case toComposer(String)
        case discarded(Reason)

        public enum Reason: Equatable, Sendable {
            case composerInUse
            case notPlainText
            case notTheOwners
        }

        public var holdsCanvasComments: Bool {
            guard case .toComposer(let text) = self else { return false }
            return !PendingMessageEdit.draftIsAbandoned(text)
        }
    }

    public static func recovery(of delivery: Delivery, composerDraft: String) -> Recovery {
        guard delivery.kind != .interruptedTurnResume, delivery.crewPayload == nil, !delivery.isCanvasComment else { return .discarded(.notTheOwners) }
        guard isPlainText(delivery.body) else { return .discarded(.notPlainText) }
        guard composerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .discarded(.composerInUse)
        }
        return .toComposer(delivery.body)
    }

    public static func isPlainText(_ body: String) -> Bool {
        ReviewTurn.split(body) == nil && AttachmentTrailer.split(body).paths.isEmpty
    }

    public struct Question: Equatable, Sendable {
        public var title: String
        public var message: String
        public var confirmLabel: String
        public var cancelLabel: String

        public init(title: String, message: String, confirmLabel: String, cancelLabel: String) {
            self.title = title
            self.message = message
            self.confirmLabel = confirmLabel
            self.cancelLabel = cancelLabel
        }
    }

    public static func question(for delivery: Delivery, composerDraft: String) -> Question {
        if AppRequest.isHidden(delivery) {
            return Question(
                title: "Delete this request?",
                message: "Unified Dev stops trying to send it. This does not stop any work the agent may already have started.",
                confirmLabel: "Delete", cancelLabel: "Keep"
            )
        }
        guard delivery.deliveredSeq != nil else {
            return question(for: recovery(of: delivery, composerDraft: composerDraft))
        }
        return Question(
            title: "Remove this retry reminder?",
            message: "The message stays in the conversation. Removing this reminder does not stop any work the agent may already have started.",
            confirmLabel: "Remove Reminder", cancelLabel: "Keep"
        )
    }

    public static func question(for recovery: Recovery) -> Question {
        let message =
            switch recovery {
            case .toComposer:
                "It leaves the queue without being sent, and its text goes back to the composer."
            case .discarded:
                "It leaves the queue without being sent, and its text is not kept."
            }
        return Question(
            title: "Delete this message?",
            message: message,
            confirmLabel: "Delete",
            cancelLabel: "Keep"
        )
    }

    public static let alreadySentSentence =
        "That message had already gone to the agent, so it was not deleted."
}
