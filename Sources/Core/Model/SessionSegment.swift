import Foundation

public struct SessionSegment: Sendable, Equatable, Identifiable {
    public let id: SessionSegmentID
    public let sessionID: SessionID
    public let agentKind: AgentKind
    public let accountID: AgentAccountID?
    public let agentSessionID: String?
    public let model: String
    public let effort: String
    public let cursorSeq: Int
    public let enteredSeq: Int
    public let isActive: Bool
    public let seedSessionID: SessionID?

    public init(
        id: SessionSegmentID,
        sessionID: SessionID,
        agentKind: AgentKind,
        accountID: AgentAccountID?,
        agentSessionID: String?,
        model: String,
        effort: String,
        cursorSeq: Int,
        enteredSeq: Int,
        isActive: Bool,
        seedSessionID: SessionID?
    ) {
        self.id = id
        self.sessionID = sessionID
        self.agentKind = agentKind
        self.accountID = accountID
        self.agentSessionID = agentSessionID
        self.model = model
        self.effort = effort
        self.cursorSeq = cursorSeq
        self.enteredSeq = enteredSeq
        self.isActive = isActive
        self.seedSessionID = seedSessionID
    }
}

public struct SessionSegmentTarget: Sendable, Equatable {
    public let agentKind: AgentKind
    public let accountID: AgentAccountID?
    public let model: String
    public let effort: String

    public init(agentKind: AgentKind, accountID: AgentAccountID?, model: String, effort: String) {
        self.agentKind = agentKind
        self.accountID = accountID
        self.model = model
        self.effort = effort
    }
}
