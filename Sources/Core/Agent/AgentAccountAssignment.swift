import Foundation

public enum AgentAccountAssignment {
    public static let noDatabase = "Unified Dev has no database open."

    public enum Target: Sendable, Equatable {
        case repo(RepoID)
        case workspace(WorkspaceID)
    }

    public struct UnknownTarget: Error, Sendable, Equatable {
        public let sentence: String
    }

    public static func target(
        _ level: AgentAccountOptions.Scope,
        repoID: RepoID?,
        workspaceID: WorkspaceID?
    ) -> Result<Target, UnknownTarget> {
        switch level {
        case .project:
            guard let repoID else { return .failure(UnknownTarget(sentence: "This project is not known.")) }
            return .success(.repo(repoID))
        case .workspace:
            guard let workspaceID else { return .failure(UnknownTarget(sentence: "This workspace is not known.")) }
            return .success(.workspace(workspaceID))
        }
    }

    public static func saveFailure(_ detail: String) -> String {
        "Could not save the account: \(detail)"
    }

    public static func choose(_ chosen: ChosenAgentAccount, forRepo id: RepoID, in store: Store) async throws {
        try await remember(chosen.home, in: store)
        try await store.chooseAgentAccount(chosen, forRepo: id)
    }

    public static func choose(
        _ chosen: ChosenAgentAccount, forWorkspace id: WorkspaceID, in store: Store
    ) async throws {
        try await remember(chosen.home, in: store)
        try await store.chooseAgentAccount(chosen, forWorkspace: id)
    }

    public static func remember(_ home: AgentAccountHome?, in store: Store) async throws {
        guard let home, home.isDefault else { return }
        try await store.addIfMissing(AgentAccountRow(
            id: home.id,
            provider: home.provider,
            directory: home.directory.path,
            isDefault: true
        ))
    }
}
