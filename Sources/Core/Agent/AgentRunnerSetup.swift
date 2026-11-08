import Foundation

public enum AgentRunnerSetup: Sendable, Equatable {
    public struct Plan: Sendable, Equatable {
        public let reuse: AgentRunnerReuse
        public let settlement: AgentSessionSettlement
        public let isSettledAfterwards: Bool

        public var retiresRunner: Bool { reuse == .retireThenBuild }
        public var keepsRunner: Bool { reuse.keepsRunner }
    }

    case refused(String)
    case ready(Plan)

    public static func decide(
        gate: AgentDeliveryGate,
        hasRunner: Bool,
        preferencesChanged: Bool,
        isSettled: Bool,
        purpose: AgentSessionSettlement.Purpose,
        settlement: AgentSessionSettlement
    ) -> AgentRunnerSetup {
        if case .refuse(let sentence) = gate { return .refused(sentence) }
        let reuse = AgentRunnerReuse.decide(
            hasRunner: hasRunner,
            preferencesChanged: preferencesChanged,
            isSettled: isSettled,
            purpose: purpose,
            settlementSwitchesSegment: settlement.switchTarget != nil
        )
        let applies = reuse.appliesSettlement(for: purpose)
        return .ready(Plan(
            reuse: reuse,
            settlement: applies ? settlement : .nothing,
            isSettledAfterwards: reuse == .reuse ? isSettled : applies
        ))
    }
}
