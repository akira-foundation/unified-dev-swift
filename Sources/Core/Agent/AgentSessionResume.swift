import Foundation

public enum AgentSessionResume: Sendable, Equatable {
    case start
    case resume(String)
    case fresh

    public static func decide(session: Session, running account: AgentAccountHome?) -> AgentSessionResume {
        guard let stored = session.agentSessionID, !stored.isEmpty else { return .start }
        guard let account else { return .resume(stored) }
        let owner = session.accountID ?? AgentAccountHome.defaultID(for: session.agentKind)
        return owner == account.id ? .resume(stored) : .fresh
    }

    public var agentSessionID: String? {
        guard case .resume(let id) = self else { return nil }
        return id
    }

    public static func recordedAccount(for session: Session, running account: AgentAccountHome?) -> AgentAccountID? {
        guard let account, session.accountID != account.id else { return nil }
        return account.id
    }

    public static func freshNotice(for provider: AgentKind) -> String {
        "This chat moved to another \(provider.label) account, which does not have its history, "
            + "so the agent started a new conversation. The transcript here is unchanged."
    }
}
