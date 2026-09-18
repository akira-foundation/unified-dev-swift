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
        collect(turn, stored: stored, live: live, storedKey: \.workspaceID, liveKey: \.workspaceID)
    }

    public static func sessions(
        _ turn: Kind,
        stored: [SessionActivity],
        live: [Live]
    ) -> Set<SessionID> {
        collect(turn, stored: stored, live: live, storedKey: \.sessionID, liveKey: \.sessionID)
    }

    public static func agentCount(
        stored: [SessionActivity],
        live: [Live],
        runningWorkspaces: Set<WorkspaceID>,
        waitingWorkspaces: Set<WorkspaceID>,
        askIsWorking: Bool
    ) -> Int {
        let working = sessions(.running, stored: stored, live: live)
            .subtracting(sessions(.awaitingPermission, stored: stored, live: live))
        let floor = runningWorkspaces.subtracting(waitingWorkspaces).count
        return max(working.count, floor) + (askIsWorking ? 1 : 0)
    }

    private static func collect<Key: Hashable>(
        _ turn: Kind,
        stored: [SessionActivity],
        live: [Live],
        storedKey: KeyPath<SessionActivity, Key>,
        liveKey: KeyPath<Live, Key>
    ) -> Set<Key> {
        let byID = index(live)
        var found: Set<Key> = []
        for row in stored where byID[row.sessionID] == nil && row.state == turn.sessionState {
            found.insert(row[keyPath: storedKey])
        }
        for entry in live where entry.says(turn) {
            found.insert(entry[keyPath: liveKey])
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
