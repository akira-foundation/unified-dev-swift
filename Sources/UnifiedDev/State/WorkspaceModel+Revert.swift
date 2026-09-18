import Foundation
import Core

extension WorkspaceModel {
    func revert(_ file: ChangedFile) async -> RevertAlert? {
        let absolute = (workspace.path as NSString).appendingPathComponent(file.path)
        let outcome = await WorktreeFileRevert.revert(file, in: workspace, refusal: revertBlocker)
        if outcome.discardsDraft {
            FileEditSession.shared.discard(path: absolute)
            DiffEditSession.shared.close(path: absolute)
        }
        if outcome.refreshesChanges {
            forgetHeldDiff(for: file.path)
            await refreshChanges()
        }
        return RevertAlert(outcome, filename: file.filename)
    }
}
