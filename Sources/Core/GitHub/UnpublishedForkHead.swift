import Foundation

extension GitHub {
    static func snapshotOfUnpublishedForkHead(
        _ branch: String, worktree: String, context: GitRepositoryContext?, maxAge: Duration
    ) async throws -> PullRequestSnapshot? {
        guard let context, !context.headIsTracked else { return nil }
        let forks = PullRequestHead.forkRepositories(in: context)
        guard !forks.isEmpty else { return nil }

        let candidates = try await pullRequestHeads(branch, worktree: worktree, context: context)
            .filter { candidate in
                PullRequestHead.repositoryKey(
                    owner: candidate.headRepositoryOwner?.login, name: candidate.headRepository?.name
                ).map(forks.contains) ?? false
            }
            .sorted { ($0.number ?? 0) > ($1.number ?? 0) }
        for candidate in candidates {
            guard let number = candidate.number, number > 0,
                  let commit = candidate.headCommit,
                  await holds(pushed: commit, on: branch, context: context, worktree: worktree),
                  let found = try? await snapshot(forNumber: number, worktree: worktree, maxAge: maxAge),
                  found.pullRequest.branch.caseInsensitiveCompare(branch) == .orderedSame
            else { continue }
            return found
        }
        return nil
    }

    private static func holds(
        pushed commit: String, on branch: String, context: GitRepositoryContext, worktree: String
    ) async -> Bool {
        let tip = "refs/heads/\(branch)"
        guard await Git.isAncestor(commit, of: tip, in: worktree) else { return false }
        if await Git.isAncestor(tip, of: commit, in: worktree) { return true }
        guard let base = context.baseTrackingRef else { return true }
        return await !Git.isAncestor(commit, of: base, in: worktree)
    }
}
