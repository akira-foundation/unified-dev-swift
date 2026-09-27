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

    func hunkDiscard(for file: ChangedFile, ignoringWhitespace: Bool) -> HunkDiscard.Availability {
        HunkDiscard.availability(
            file: file, ignoringWhitespace: ignoringWhitespace, blocker: revertBlocker,
            hasUnsavedEdits: hasUnsavedEdits(file)
        )
    }

    func discard(_ hunk: DiffHunk, of file: ChangedFile) async -> RevertAlert? {
        let refusal = revertBlocker ?? (hasUnsavedEdits(file) ? HunkDiscard.draftIsOpen : nil)
        let outcome = await WorktreeHunkDiscard.discard(
            hunk, of: file, in: workspace, scope: diffScope, refusal: refusal
        )
        if outcome.refreshesChanges {
            forgetHeldDiff(for: file.path)
            await refreshChanges()
        }
        return RevertAlert(outcome, filename: file.filename)
    }

    private func hasUnsavedEdits(_ file: ChangedFile) -> Bool {
        let absolute = (workspace.path as NSString).appendingPathComponent(file.path)
        return FileEditSession.shared.isDirty(absolute) || DiffEditSession.shared.isEdited(absolute)
    }
}
