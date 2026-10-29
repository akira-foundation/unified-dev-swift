import Foundation

public enum AgentAccountUsage {
    public static func runningWorkspaces(under home: AgentAccountHome, store: Store) async throws -> [String] {
        var names: Set<String> = []
        for activity in try await store.sessionActivity() {
            guard let session = try await store.session(id: activity.sessionID),
                  session.agentKind == home.provider,
                  let workspace = try await store.workspace(id: activity.workspaceID)
            else { continue }
            let repo = try await store.repo(id: workspace.repoID)
            guard (workspace.accountID ?? repo?.accountID) == home.id else { continue }
            names.insert(workspace.name)
        }
        return names.sorted()
    }
}
