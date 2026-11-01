import Foundation

extension Store {
    @discardableResult
    public func setOrchestrator(_ isOrchestrator: Bool, workspaceID: WorkspaceID) throws -> Workspace? {
        guard var row = try workspace(id: workspaceID) else { return nil }
        guard row.isOrchestrator != isOrchestrator else { return row }
        if isOrchestrator {
            let neighbours = try workspaces(repoID: row.repoID, includeArchived: true)
            if case .refused(let sentence) = OrchestratorRole.assignment(of: row, among: neighbours) {
                throw WorkspaceError.orchestratorRefused(sentence)
            }
            row.pinned = true
        }
        row.isOrchestrator = isOrchestrator
        return try upsert(row)
    }
}
