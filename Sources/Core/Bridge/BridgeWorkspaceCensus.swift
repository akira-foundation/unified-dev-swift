import Foundation

public struct BridgeWorkspaceCensus: Sendable {
    public struct Counts: Sendable, Hashable {
        public var workspaces: Int
        public var agentsRunning: Int
        public var awaitingPermission: Int

        public init(workspaces: Int = 0, agentsRunning: Int = 0, awaitingPermission: Int = 0) {
            self.workspaces = workspaces
            self.agentsRunning = agentsRunning
            self.awaitingPermission = awaitingPermission
        }
    }

    public let all: [Workspace]

    private let running: Set<WorkspaceID>
    private let awaiting: Set<WorkspaceID>

    public init(all: [Workspace], running: Set<WorkspaceID>, awaitingPermission: Set<WorkspaceID>) {
        self.all = all
        self.running = running
        self.awaiting = awaitingPermission
    }

    public static func read(from store: Store) async throws -> BridgeWorkspaceCensus {
        let all = try await store.workspaces(includeArchived: true)
        let activity = try await store.sessionActivity()
        return BridgeWorkspaceCensus(
            all: all,
            running: AgentTurns.workspaces(.running, stored: activity, live: []),
            awaitingPermission: AgentTurns.workspaces(
                .awaitingPermission, stored: activity, live: []
            )
        )
    }

    public func listing(repoID: RepoID? = nil, includeArchived: Bool = false) -> [Workspace] {
        all.filter { workspace in
            if let repoID, workspace.repoID != repoID { return false }
            return includeArchived || workspace.state != .archived
        }
    }

    public func isRunning(_ workspaceID: WorkspaceID) -> Bool { running.contains(workspaceID) }

    public func isAwaitingPermission(_ workspaceID: WorkspaceID) -> Bool {
        awaiting.contains(workspaceID)
    }

    public func counts(repoID: RepoID) -> Counts {
        let rows = listing(repoID: repoID)
        return Counts(
            workspaces: rows.count,
            agentsRunning: rows.count { isRunning($0.id) },
            awaitingPermission: rows.count { isAwaitingPermission($0.id) }
        )
    }
}
