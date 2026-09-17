import Foundation

public enum DeliverySteer {
    public static func canSteer(_ delivery: Delivery, hold: DeliveryHold, on agent: AgentKind) -> Bool {
        guard hold == .turn, !agent.acceptsMidTurnMessage else { return false }
        return delivery.isPending && delivery.kind == .owner && delivery.crewPayload == nil
    }

    public static func queue(after chosen: Delivery, from pending: [Delivery]) -> [Delivery] {
        pending.filter { $0.id != chosen.id }
    }
}
