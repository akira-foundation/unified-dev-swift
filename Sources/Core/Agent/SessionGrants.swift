import Foundation
import Synchronization

final class SessionGrants: Sendable {
    private let store: Store
    private let workspaceID: WorkspaceID?
    private let cachedRepoID = Mutex<RepoID?>(nil)

    init(store: Store, workspaceID: WorkspaceID?) {
        self.store = store
        self.workspaceID = workspaceID
    }

    func repoID() async -> RepoID? {
        if let cached = cachedRepoID.withLock({ $0 }) { return cached }
        guard let workspaceID,
              let workspace = try? await store.workspace(id: workspaceID) else { return nil }
        cachedRepoID.withLock { $0 = workspace.repoID }
        return workspace.repoID
    }

    func matching(_ ask: PermissionAsk) async -> [PermissionGrant]? {
        guard ask.canWiden, let repoID = await repoID() else { return nil }
        guard let grants = try? await store.permissionGrants(repoID: repoID) else { return nil }
        return PermissionGrantIndex.match(ask: ask, grants: grants)
    }

    func recordUse(of grants: [PermissionGrant]) async {
        for grant in grants {
            try? await store.recordPermissionGrantUse(id: grant.id)
        }
    }

    func record(_ decision: PermissionDecision, from ask: PermissionAsk) async {
        guard let repoID = await repoID() else { return }
        for grant in PermissionGrant.all(granting: decision, from: ask, repoID: repoID) {
            _ = try? await store.upsert(grant)
        }
    }
}
