import Foundation
import Core

extension WorkspaceModel {
    func revert(_ file: ChangedFile) async -> String? {
        let absolute = (workspace.path as NSString).appendingPathComponent(file.path)
        let outcome = await WorktreeFileRevert.revert(file, in: workspace)
        if outcome.discardsDraft {
            FileEditSession.shared.discard(path: absolute)
            DiffEditSession.shared.close(path: absolute)
        }
        forgetHeldDiff(for: file.path)
        await refreshChanges()
        if case let .failed(detail) = outcome { return detail }
        return nil
    }
}
