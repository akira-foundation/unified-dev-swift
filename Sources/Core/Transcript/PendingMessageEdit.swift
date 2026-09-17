import Foundation

public enum PendingMessageEdit {
    public static func canEdit(_ delivery: Delivery) -> Bool {
        PendingMessageDiscard.canDiscard(delivery) && PendingMessageDiscard.isPlainText(delivery.body)
    }

    public static func draft(taking delivery: Delivery, into composerDraft: String) -> String {
        guard !composerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return delivery.body
        }
        return delivery.body + "\n\n" + composerDraft
    }

    public static let alreadySentSentence =
        "That message had already gone to the agent, so it could not be edited."
}
