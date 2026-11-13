import Foundation

public enum MergeArchiveInFlightRead {
    public typealias PullRequestLookup = @Sendable (_ branch: String, _ worktree: String) async throws
        -> [BranchPullRequest]

    public static func objection(
        worktree: String,
        mergedBranch: String?,
        lookup: PullRequestLookup = { try await GitHub.branchPullRequests($0, worktree: $1) }
    ) async -> String? {
        do {
            let branches = try await branches(worktree: worktree, mergedBranch: mergedBranch, lookup: lookup)
            return MergeArchiveInFlight.objection(branches)
        } catch {
            return "Unified Dev could not read the other branches of this worktree, so it cannot tell "
                + "whether work is still in flight there."
        }
    }

    static func branches(
        worktree: String, mergedBranch: String?, lookup: PullRequestLookup
    ) async throws -> [BranchInFlight] {
        let reflog = try await Git.run(["reflog", "show", "--format=%gs", "HEAD"], in: worktree)
        let current = try await Git.run(["symbolic-ref", "--quiet", "--short", "HEAD"], in: worktree)
        let local = try await Git.check(
            ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: worktree
        )
        let checkedOut = current.ok ? current.trimmed : nil
        let names = MergeArchiveInFlight.candidates(
            checkedOut: reflog.ok ? MergeArchiveInFlight.checkedOutBranches(reflogSubjects: reflog.stdout) : [],
            current: checkedOut,
            localBranches: Set(local.stdout.split(whereSeparator: \.isNewline).map(String.init)),
            merged: mergedBranch ?? checkedOut ?? ""
        )
        var standings: [BranchInFlight] = []
        for name in names {
            let pullRequests = try await lookup(name, worktree)
            let unpushed = try await unpushedCommits(
                of: name, excluding: MergeArchiveInFlight.excludedHeads(pullRequests), in: worktree
            )
            standings.append(
                MergeArchiveInFlight.standing(branch: name, pullRequests: pullRequests, unpushedCommits: unpushed)
            )
        }
        return standings
    }

    private static func unpushedCommits(
        of branch: String, excluding heads: [String], in worktree: String
    ) async throws -> Int {
        var known: [String] = []
        for head in heads where Git.isCommitID(head) {
            if await Git.revision(of: head, in: worktree) != nil { known.append(head) }
        }
        let count = try await Git.check(
            ["rev-list", "--count", "refs/heads/\(branch)", "--not", "--remotes"] + known, in: worktree
        )
        return Int(count.trimmed) ?? 0
    }
}
