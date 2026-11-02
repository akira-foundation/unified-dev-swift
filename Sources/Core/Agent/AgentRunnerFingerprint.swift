import Foundation

public struct AgentRunnerFingerprint: Sendable, Equatable {
    public let model: String
    public let effort: String
    public let permissionMode: PermissionMode
    public let agentKind: AgentKind
    public let account: AgentAccountID?
    public let accountDirectory: String?
    public let orchestrates: Bool

    public init(session: Session, account: AgentAccountHome?, orchestrates: Bool) {
        model = session.model
        effort = session.effort
        permissionMode = session.permissionMode
        agentKind = session.agentKind
        self.account = account?.id
        accountDirectory = account?.directory.path
        self.orchestrates = orchestrates
    }
}
