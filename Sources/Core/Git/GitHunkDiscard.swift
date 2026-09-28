import Foundation

extension Git {
    public static func discardHunk(
        _ hunk: DiffHunk, of file: ChangedFile, worktree: String, base: String, scope: DiffScope
    ) async throws {
        guard HunkDiscard.offers(file) else { throw HunkDiscardRefusal.notOffered }

        let current = try await patch(worktree: worktree, base: base, file: file, scope: scope)
        let parsed = DiffParser.parse(current)
        guard parsed.count == 1, let shown = parsed.first,
              HunkDiscard.offers(file, in: shown) else { throw HunkDiscardRefusal.notOffered }
        guard let isolated = HunkPatch.isolate(hunk, from: current) else {
            throw HunkDiscardRefusal.changed
        }

        let reverse = ["apply", "--reverse", "--whitespace=nowarn"]
        if try await run(reverse + ["--index", "--check"], in: worktree, stdin: isolated).ok {
            try await check(reverse + ["--index"], in: worktree, stdin: isolated)
            return
        }

        guard try await !run(reverse + ["--cached", "--check"], in: worktree, stdin: isolated).ok else {
            throw HunkDiscardRefusal.indexDiffers
        }

        let worktreeCheck = try await run(reverse + ["--check"], in: worktree, stdin: isolated)
        guard worktreeCheck.ok else {
            throw HunkDiscardRefusal.doesNotApply(
                worktreeCheck.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        try await check(reverse, in: worktree, stdin: isolated)
    }
}
