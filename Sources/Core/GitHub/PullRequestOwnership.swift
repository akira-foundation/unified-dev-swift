import Foundation

public enum PullRequestOwnership {
    public static func belongs(
        _ pullRequest: PullRequest,
        toWorkspaceStartedAt startedAt: Date,
        checkedOutAs checkedOutNumber: Int?
    ) -> Bool {
        if let checkedOutNumber { return pullRequest.number == checkedOutNumber }
        guard let closedAt = pullRequest.closedAt else { return true }
        return closedAt >= startedAt
    }

    public static func choose(
        from matches: [PullRequestHeadMatch],
        startedAt: Date,
        checkedOutAs checkedOutNumber: Int?
    ) -> Int? {
        if let checkedOutNumber {
            return matches.contains { $0.number == checkedOutNumber } ? checkedOutNumber : nil
        }
        return matches
            .sorted { $0.number > $1.number }
            .first { $0.closedAt.map { closed in closed >= startedAt } ?? true }?
            .number
    }
}

public struct PullRequestHeadMatch: Sendable, Hashable {
    public let number: Int
    public let closedAt: Date?

    public init(number: Int, closedAt: Date?) {
        self.number = number
        self.closedAt = closedAt
    }
}

public extension Git {
    static func checkedOutPullRequest(branch: String, worktree: String) async -> Int? {
        guard isValidBranchName(branch) else { return nil }
        guard let result = try? await run(
            ["config", "--get", "branch.\(branch).merge"], in: worktree
        ), result.ok else { return nil }

        let reference = result.trimmed
        let prefix = "refs/pull/"
        let suffix = "/head"
        guard reference.hasPrefix(prefix), reference.hasSuffix(suffix) else { return nil }
        let digits = reference.dropFirst(prefix.count).dropLast(suffix.count)
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return Int(digits)
    }
}

public extension GitHub {
    static func pullRequest(
        for workspace: Workspace, maxAge: Duration = .zero
    ) async throws -> PullRequest? {
        try await pullRequest(
            for: workspace, onBranch: await headBranch(of: workspace), maxAge: maxAge
        )
    }

    static func headBranch(of workspace: Workspace) async -> String {
        let checkedOut = try? await Git.currentBranch(of: workspace.path)
        return PullRequestHead.branch(
            recorded: workspace.branch, checkedOut: checkedOut, base: workspace.baseBranch
        )
    }

    private static func pullRequest(
        for workspace: Workspace, onBranch head: String, maxAge: Duration
    ) async throws -> PullRequest? {
        try await snapshot(for: workspace, onBranch: head, maxAge: maxAge)?.pullRequest
    }

    internal static func snapshot(
        for workspace: Workspace, onBranch head: String, maxAge: Duration
    ) async throws -> PullRequestSnapshot? {
        if let found = try await snapshot(
            forBranch: head, worktree: workspace.path, maxAge: maxAge
        ), await owns(found.pullRequest, workspace: workspace, onBranch: head) {
            return found
        }

        if let number = workspace.pullRequestNumber,
           let found = try await snapshot(forNumber: number, worktree: workspace.path, maxAge: maxAge) {
            return found
        }

        let branchIsGone = await !Git.branchExists(head, in: workspace.path)
        guard branchIsGone else { return nil }

        let matches = try await pullRequestsWithHead(head, worktree: workspace.path)
        guard let chosen = PullRequestOwnership.choose(
            from: matches,
            startedAt: workspace.createdAt,
            checkedOutAs: await Git.checkedOutPullRequest(branch: head, worktree: workspace.path)
        ) else { return nil }
        return try await snapshot(forNumber: chosen, worktree: workspace.path, maxAge: maxAge)
    }

    static func checks(for workspace: Workspace, maxAge: Duration = .zero) async throws -> [CheckRun]? {
        let head = await headBranch(of: workspace)
        guard let found = try await snapshot(
            for: workspace, onBranch: head, maxAge: maxAge
        ) else { return [] }
        return found.pullRequest.checks == .unavailable ? nil : found.runs
    }

    private static func owns(
        _ pullRequest: PullRequest, workspace: Workspace, onBranch head: String
    ) async -> Bool {
        let checkedOut = await Git.checkedOutPullRequest(branch: head, worktree: workspace.path)
        return PullRequestOwnership.belongs(
            pullRequest, toWorkspaceStartedAt: workspace.createdAt, checkedOutAs: checkedOut
        )
    }
}
