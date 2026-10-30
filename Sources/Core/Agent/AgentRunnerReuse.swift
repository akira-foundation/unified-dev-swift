import Foundation

public enum AgentRunnerReuse: Sendable, Equatable {
    case build
    case reuse
    case settleThenReuse
    case retireThenBuild

    public static func decide(
        hasRunner: Bool,
        preferencesChanged: Bool,
        isSettled: Bool,
        purpose: AgentSessionSettlement.Purpose,
        settlementClearsStoredID: Bool
    ) -> AgentRunnerReuse {
        guard hasRunner else { return .build }
        if preferencesChanged { return .retireThenBuild }
        guard purpose == .sending, !isSettled else { return .reuse }
        return settlementClearsStoredID ? .retireThenBuild : .settleThenReuse
    }

    public func appliesSettlement(for purpose: AgentSessionSettlement.Purpose) -> Bool {
        purpose == .sending && self != .reuse
    }

    public var keepsRunner: Bool {
        self == .reuse || self == .settleThenReuse
    }
}
