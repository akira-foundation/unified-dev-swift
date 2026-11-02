import Foundation

extension Store {
    @discardableResult
    public func setOrchestrator(_ isOrchestrator: Bool, workspaceID: WorkspaceID) throws -> Workspace? {
        guard let row = try workspace(id: workspaceID) else { return nil }
        guard row.isOrchestrator != isOrchestrator else { return row }
        if isOrchestrator {
            let neighbours = try workspaces(repoID: row.repoID, includeArchived: true)
            if case .refused(let sentence) = OrchestratorRole.assignment(of: row, among: neighbours) {
                throw WorkspaceError.orchestratorRefused(sentence)
            }
        }
        return try update(workspaceID: workspaceID) { $0.isOrchestrator = isOrchestrator }
    }
}
