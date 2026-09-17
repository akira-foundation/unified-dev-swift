import Foundation

public enum PendingMessageReturn {
    public static func canReturn(_ delivery: Delivery) -> Bool {
        delivery.state == .pending && delivery.kind == .owner
            && delivery.crewPayload == nil
            && PendingMessageEdit.canEdit(delivery)
    }

    public static func returning(from pending: [Delivery]) -> [Delivery] {
        pending.filter(canReturn)
    }

    public static func keeping(from pending: [Delivery]) -> [Delivery] {
        pending.filter { !canReturn($0) }
    }

    public static func draft(taking deliveries: [Delivery], into composerDraft: String) -> String {
        deliveries.reversed().reduce(composerDraft) {
            PendingMessageEdit.draft(taking: $1, into: $0)
        }
    }
}
