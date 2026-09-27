import Foundation

public enum WorktreeHunkDiscard {
    public static func discard(
        _ hunk: DiffHunk, of file: ChangedFile, in workspace: Workspace, scope: DiffScope, refusal: String?
    ) async -> RevertOutcome {
        if let refusal { return .refused(refusal) }
        do {
            try await Git.discardHunk(
                hunk, of: file, worktree: workspace.path, base: workspace.baseBranch, scope: scope
            )
            return .reverted
        } catch let refused as HunkDiscardRefusal {
            return .refused(refused.errorDescription ?? "")
        } catch let error as ShellError {
            return .failed(error.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
