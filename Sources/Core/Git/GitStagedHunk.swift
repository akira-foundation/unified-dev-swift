import Foundation

extension Git {
    public static func stagedHunk(
        _ hunk: DiffHunk, of file: ChangedFile, worktree: String, base: String, scope: DiffScope
    ) async -> HunkDiscard.Staged {
        do {
            guard try await stagedContentDiffers(file, in: worktree) else { return .clean }

            let plan = try await hunkDiscardPlan(
                hunk, of: file, worktree: worktree, base: base, scope: scope
            )
            guard plan.hasPreimage else { return .holdsAnotherVersion }

            let held = try await run(
                ["apply", "--reverse", "--whitespace=nowarn", "--cached", "--check"],
                in: worktree, stdin: plan.isolated
            )
            return held.ok ? .holdsTheHunk : .holdsAnotherVersion
        } catch {
            return .unreadable
        }
    }

    static func stagedContentDiffers(_ file: ChangedFile, in worktree: String) async throws -> Bool {
        let staged = try await run(["rev-parse", "--verify", "--quiet", ":" + file.path], in: worktree)
        let committed = try await run(
            ["rev-parse", "--verify", "--quiet", "HEAD:" + (file.oldPath ?? file.path)], in: worktree
        )
        guard staged.ok, committed.ok else { return true }
        return staged.trimmed != committed.trimmed
    }
}
