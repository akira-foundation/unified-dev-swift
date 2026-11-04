import Foundation

public enum AgentDeliveryGate: Sendable, Equatable {
    case proceed
    case refuse(String)

    public static let rewindHeld = "Resolve the interrupted rewind before sending more messages."

    public static func decide(
        purpose: AgentSessionSettlement.Purpose,
        isArchiving: Bool,
        isHeld: Bool
    ) -> AgentDeliveryGate {
        if isArchiving { return .refuse(AgentTurnRestart.workspaceArchiving) }
        guard purpose == .sending, isHeld else { return .proceed }
        return .refuse(rewindHeld)
    }
}
