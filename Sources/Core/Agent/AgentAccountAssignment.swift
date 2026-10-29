import Foundation

public enum AgentAccountAssignment {
    public static func choose(_ home: AgentAccountHome?, forRepo id: RepoID, in store: Store) async throws {
        try await remember(home, in: store)
        try await store.update(repoID: id, accountID: home?.id)
    }

    public static func choose(_ home: AgentAccountHome?, forWorkspace id: WorkspaceID, in store: Store) async throws {
        try await remember(home, in: store)
        try await store.update(workspaceID: id, accountID: home?.id)
    }

    private static func remember(_ home: AgentAccountHome?, in store: Store) async throws {
        guard let home, home.isDefault else { return }
        let known = try await store.agentAccounts()
        guard !known.contains(where: { $0.id == home.id }) else { return }
        try await store.add(AgentAccountRow(
            id: home.id,
            provider: home.provider,
            directory: home.directory.path,
            isDefault: true
        ))
    }
}
