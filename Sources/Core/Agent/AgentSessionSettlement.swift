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
        guard hasHistory else {
            guard session.accountID != account.id else { return .nothing }
            return AgentSessionSettlement(clearsStoredID: false, notice: nil, recordedAccount: account.id)
        }
        if isDeliberateSwitch {
            return AgentSessionSettlement(clearsStoredID: true, notice: nil, recordedAccount: account.id)
        }
        guard session.accountID.map({ $0 != account.id }) == true else { return .nothing }
        return AgentSessionSettlement(
            clearsStoredID: false,
            notice: elsewhereNotice(for: session.agentKind),
            recordedAccount: nil
        )
    }

    public static func resumable(session: Session, account: AgentAccountHome?) -> String? {
        guard let account, let owner = session.accountID, owner != account.id else {
            return session.agentSessionID
        }
        return nil
    }

    public static func elsewhereNotice(for provider: AgentKind) -> String {
        "This chat belongs to another \(provider.label) account and Unified Dev has left it there, "
            + "so the agent running here may not find this conversation."
    }

    public static func resolutionFailure(_ detail: String) -> String {
        "Unified Dev could not work out which account to run under: \(detail)"
    }

    public static func writeFailure(_ detail: String) -> String {
        "Unified Dev could not record which account this chat runs under, so it did not start the agent: \(detail)"
    }
}
