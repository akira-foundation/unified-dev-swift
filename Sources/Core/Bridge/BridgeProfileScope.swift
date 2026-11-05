import Foundation

public enum BridgeProfileScope {
    public static func profile(of identity: BridgeIdentity, store: Store) async throws -> ProfileID? {
        switch identity.role {
        case .owner:
            return try await store.activeProfileID()
        case .workspace:
            guard let workspaceID = identity.workspaceID,
                  let workspace = try await store.workspace(id: workspaceID)
            else { return nil }
            return try await store.repo(id: workspace.repoID)?.profileID
        }
    }

    public static func repos(for identity: BridgeIdentity, store: Store) async throws -> [Repo] {
        guard let profile = try await profile(of: identity, store: store) else { return [] }
        return ProfileScope.repos(try await store.repos(), in: profile)
    }

    public static func workspaces(
        for identity: BridgeIdentity, store: Store, includeArchived: Bool = false
    ) async throws -> [Workspace] {
        try await keeping(try await store.workspaces(includeArchived: includeArchived), for: identity, store: store)
    }

    public static func workspace(
        id: WorkspaceID, for identity: BridgeIdentity, store: Store
    ) async throws -> Workspace? {
        guard let row = try await store.workspace(id: id) else { return nil }
        return try await keeping([row], for: identity, store: store).first
    }

    public static func keeping(
        _ rows: [Workspace], for identity: BridgeIdentity, store: Store
    ) async throws -> [Workspace] {
        guard let profile = try await profile(of: identity, store: store) else { return [] }
        return ProfileScope.workspaces(rows, repos: try await store.repos(), in: profile)
    }

    public static func belongsElsewhere(path: String) -> String {
        "The repository at \(path) belongs to another profile, and a caller only reaches projects in its "
            + "own. Retrying will not change that."
    }
}
