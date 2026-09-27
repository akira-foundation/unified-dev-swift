import Foundation

extension Git {
    public static func discardHunk(
        _ hunk: DiffHunk, of file: ChangedFile, worktree: String, base: String, scope: DiffScope
    ) async throws {
        guard HunkDiscard.offers(file) else { throw HunkDiscardRefusal.notOffered }

        let current = try await patch(worktree: worktree, base: base, file: file, scope: scope)
        guard let isolated = HunkPatch.isolate(hunk, from: current) else {
            throw HunkDiscardRefusal.changed
        }

        let reverse = ["apply", "--reverse", "--whitespace=nowarn"]
        let worktreeCheck = try await run(reverse + ["--check"], in: worktree, stdin: isolated)
        guard worktreeCheck.ok else {
            throw HunkDiscardRefusal.doesNotApply(
                worktreeCheck.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        let indexCheck = try await run(reverse + ["--cached", "--check"], in: worktree, stdin: isolated)

        try await check(reverse, in: worktree, stdin: isolated)
        if indexCheck.ok {
            try await check(reverse + ["--cached"], in: worktree, stdin: isolated)
        }
    }
}
