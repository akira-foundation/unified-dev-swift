import Foundation

public struct AgentSessionSettlement: Sendable, Equatable {
    public enum Purpose: Sendable, Equatable {
        case sending
        case answering
    }

    public let clearsStoredID: Bool
    public let notice: String?
    public let recordedAccount: AgentAccountID?

    public static let nothing = AgentSessionSettlement(clearsStoredID: false, notice: nil, recordedAccount: nil)

    public var changesNothing: Bool { self == .nothing }

    public static func decide(
        session: Session,
        account: AgentAccountHome?,
        purpose: Purpose,
        isDeliberateSwitch: Bool
    ) -> AgentSessionSettlement {
        guard purpose == .sending, let account else { return .nothing }
        let hasHistory = !(session.agentSessionID ?? "").isEmpty
        let isKnownToBeElsewhere = session.accountID.map { $0 != account.id } ?? false
        if hasHistory, isDeliberateSwitch || isKnownToBeElsewhere {
            return AgentSessionSettlement(
                clearsStoredID: true,
                notice: isDeliberateSwitch ? nil : freshNotice(for: session.agentKind),
                recordedAccount: account.id
            )
        }
        guard !hasHistory, session.accountID != account.id else { return .nothing }
        return AgentSessionSettlement(clearsStoredID: false, notice: nil, recordedAccount: account.id)
    }

    public static func freshNotice(for provider: AgentKind) -> String {
        "This chat moved to another \(provider.label) account, which does not have its history, "
            + "so the agent started a new conversation. The transcript here is unchanged."
    }

    public static func resolutionFailure(_ detail: String) -> String {
        "Unified Dev could not work out which account to run under: \(detail)"
    }

    public static func writeFailure(_ detail: String) -> String {
        "Unified Dev could not record which account this chat runs under, so it did not start the agent: \(detail)"
    }
}
