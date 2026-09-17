import Foundation

public enum SendingSlot {
    public enum Drawing: Sendable, Equatable {
        case ownerTurn
        case workspaceMessage(CrewMessage)
        case crewMessage(CrewMessage)
    }

    public static func drawing(of delivery: Delivery) -> Drawing {
        guard let crew = delivery.crewMessage else { return .ownerTurn }
        return crew.event == .relayed ? .workspaceMessage(crew) : .crewMessage(crew)
    }

    public static func retires(_ sending: Delivery?, onPersisting kind: MessageKind) -> Bool {
        guard let sending else { return false }
        switch kind {
        case .user: return true
        case .crew: return sending.crewPayload != nil
        case .assistantText, .thinking, .toolUse, .toolResult, .permissionAsk, .result, .error,
             .system, .notice:
            return false
        }
    }
}
