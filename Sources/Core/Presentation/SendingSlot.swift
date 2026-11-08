import Foundation

public enum SendingSlot {
    public enum Drawing: Sendable, Equatable {
        case ownerTurn
        case workspaceMessage(CrewMessage)
        case crewMessage(CrewMessage)
        case stuckRequest
    }

    public static func drawing(of delivery: Delivery) -> Drawing? {
        if InterruptedTurnResume.isResume(delivery) { return nil }
        guard let crew = delivery.crewMessage else { return .ownerTurn }
        if crew.event == .appRequest { return AppRequest.isStuck(delivery) ? .stuckRequest : nil }
        return drawing(of: crew)
    }

    public static func drawing(of crew: CrewMessage) -> Drawing? {
        guard crew.event != .appRequest, !crew.text.isEmpty else { return nil }
        return crew.event == .relayed ? .workspaceMessage(crew) : .crewMessage(crew)
    }

    public static func retires(_ sending: Delivery?, onPersisting kind: MessageKind) -> Bool {
        guard let sending else { return false }
        switch kind {
        case .user: return true
        case .crew: return sending.crewPayload != nil
        case .handoff: return InterruptedTurnResume.isResume(sending)
        case .assistantText, .thinking, .toolUse, .toolResult, .permissionAsk, .result, .error,
             .system, .notice, .suggestion:
            return false
        }
    }
}
