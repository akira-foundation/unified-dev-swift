import Foundation

public struct SessionActivity: Sendable, Hashable {
    public var sessionID: SessionID
    public var workspaceID: WorkspaceID
    public var state: SessionState

    public init(sessionID: SessionID, workspaceID: WorkspaceID, state: SessionState) {
        self.sessionID = sessionID
        self.workspaceID = workspaceID
        self.state = state
    }
}

public enum AgentTurns {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case running
        case awaitingPermission

        public var sessionState: SessionState {
            switch self {
            case .running: .running
            case .awaitingPermission: .waiting
            }
        }
    }

    public struct Live: Sendable, Hashable {
        public var sessionID: SessionID
        public var workspaceID: WorkspaceID
        public var isRunning: Bool
        public var isAwaitingPermission: Bool

        public init(
            sessionID: SessionID,
            workspaceID: WorkspaceID,
            isRunning: Bool,
            isAwaitingPermission: Bool
        ) {
            self.sessionID = sessionID
            self.workspaceID = workspaceID
            self.isRunning = isRunning
            self.isAwaitingPermission = isAwaitingPermission
        }

        public func says(_ turn: Kind) -> Bool {
            switch turn {
            case .running: isRunning
            case .awaitingPermission: isAwaitingPermission
            }
        }
    }

    public static func session(_ turn: Kind, state: SessionState, live: Live?) -> Bool {
        if let live { return live.says(turn) }
        return state == turn.sessionState
    }

    public static func workspace(_ turn: Kind, sessions: [Session], live: [Live]) -> Bool {
        let byID = index(live)
        return sessions.contains { session(turn, state: $0.state, live: byID[$0.id]) }
    }

    public static func workspaces(
        _ turn: Kind,
        stored: [SessionActivity],
        live: [Live]
    ) -> Set<WorkspaceID> {
        let byID = index(live)
        var found: Set<WorkspaceID> = []

        for row in stored where byID[row.sessionID] == nil {
            if row.state == turn.sessionState { found.insert(row.workspaceID) }
        }
        for entry in live where entry.says(turn) {
            found.insert(entry.workspaceID)
        }

        return found
    }

    public static func sessions(
        _ turn: Kind,
        stored: [SessionActivity],
        live: [Live]
    ) -> Set<SessionID> {
        let byID = index(live)
        var found: Set<SessionID> = []
        for row in stored where byID[row.sessionID] == nil && row.state == turn.sessionState {
            found.insert(row.sessionID)
        }
        for entry in live where entry.says(turn) {
            found.insert(entry.sessionID)
        }
        return found
    }

    public static func isMidTurn(_ says: (Kind) -> Bool) -> Bool {
        Kind.allCases.contains(where: says)
    }

    private static func index(_ live: [Live]) -> [SessionID: Live] {
        Dictionary(live.map { ($0.sessionID, $0) }, uniquingKeysWith: { _, latest in latest })
    }
}
