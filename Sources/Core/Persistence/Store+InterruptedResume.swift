import Foundation

extension Store {
    public struct TurnReading: Sendable, Equatable {
        public var cause: TurnStopCause
        public var hasOwnerTurn: Bool
    }

    static let stopCauseWindow = 200

    public func lastTurnReading(sessionID: SessionID, agent: AgentKind, newestSeq: Int) throws -> TurnReading {
        TurnReading(
            cause: TurnStopCause.ofLastTurn(
                messages: try messages(sessionID: sessionID, afterSeq: newestSeq - Self.stopCauseWindow), agent: agent
            ),
            hasOwnerTurn: try hasOwnerTurn(sessionID: sessionID)
        )
    }

    public func releaseOrDropClaim(of delivery: Delivery) throws {
        if InterruptedTurnResume.isResume(delivery) {
            try dropUnstartedResumes(sessionID: delivery.targetSessionID)
        } else {
            try releaseDeliveryClaim(id: delivery.id)
        }
    }
}
