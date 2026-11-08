import Foundation

public enum AgentAccountUsage {
    public static func runningWorkspaces(
        under home: AgentAccountHome,
        store: Store,
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes()
    ) async throws -> [String] {
        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(), defaults: defaults
        )
        let book = try await store.agentAccountChoices()
        var names: Set<String> = []
        for activity in try await store.sessionActivity() {
            guard let session = try await store.session(id: activity.sessionID),
                  session.agentKind == home.provider,
                  let workspace = try await store.workspace(id: activity.workspaceID)
            else { continue }
            let stored = book.choices(repoID: workspace.repoID)
            let choice = AgentAccountChoice.resolve(
                provider: session.agentKind,
                project: stored.project[session.agentKind],
                profile: stored.profile[session.agentKind],
                standings: book.reachable(standings, forRepo: workspace.repoID)
            )
            guard choice.home?.id == home.id else { continue }
            names.insert(workspace.name)
        }
        return names.sorted()
    }
}
