import AppIntents
import Core

struct WorkspaceEntityQuery: EntityStringQuery {
    func entities(for identifiers: [WorkspaceEntity.ID]) async throws -> [WorkspaceEntity] {
        let store = try await IntentDatabase.store()
        let wanted = Set(identifiers)
        let workspaces = try await store.workspaces(includeArchived: true)
            .filter { wanted.contains($0.id) }
        return try await WorkspaceLookup.entities(
            for: workspaces, store: store, includePullRequests: false
        )
    }

    func suggestedEntities() async throws -> [WorkspaceEntity] {
        let store = try await IntentDatabase.store()
        return try await WorkspaceLookup.entities(
            for: try await store.workspaces(), store: store, includePullRequests: false
        )
    }

    func entities(matching string: String) async throws -> [WorkspaceEntity] {
        let needle = WorkspaceSearch.needle(string)
        guard !needle.isEmpty else { return try await suggestedEntities() }

        let store = try await IntentDatabase.store()
        var reposByID: [RepoID: Repo] = [:]
        for repo in try await store.repos() { reposByID[repo.id] = repo }
        let workspaces = try await store.workspaces().filter {
            WorkspaceSearch.match(
                workspace: $0, repo: reposByID[$0.repoID], needle: needle
            ) != nil
        }
        return try await WorkspaceLookup.entities(
            for: workspaces, store: store, includePullRequests: false
        )
    }
}
