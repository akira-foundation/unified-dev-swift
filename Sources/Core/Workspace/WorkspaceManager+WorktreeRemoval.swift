import Foundation

extension WorkspaceManager {
    func removeWorktree(of repo: Repo, at path: String, force: Bool) async throws {
        let workspaces = try await store.workspaces(repoID: repo.id)
        if let objection = OrchestratorRole.removalObjection(toWorktreeAt: path, among: workspaces) {
            throw WorkspaceError.orchestratorRefused(objection)
        }
        try await Git.removeWorktree(repo: repo.path, path: path, force: force)
    }

    func discardFreshWorktree(of repo: Repo, at path: String) async {
        try? await Git.removeWorktree(repo: repo.path, path: path, force: true)
    }
}
