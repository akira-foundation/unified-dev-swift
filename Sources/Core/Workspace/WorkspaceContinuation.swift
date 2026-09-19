import Foundation

public struct ContinuationFacts: Sendable, Hashable {
    public var mergedBranch: String
    public var checkedOutBranch: String?
    public var baseBranch: String
    public var isPullRequestMerged: Bool
    public var isAgentMidTurn: Bool
    public var hasOperationInProgress: Bool
    public var takenBranches: Set<String>

    public init(
        mergedBranch: String,
        checkedOutBranch: String?,
        baseBranch: String,
        isPullRequestMerged: Bool = false,
        isAgentMidTurn: Bool = false,
        hasOperationInProgress: Bool = false,
        takenBranches: Set<String> = []
    ) {
        self.mergedBranch = mergedBranch
        self.checkedOutBranch = checkedOutBranch
        self.baseBranch = baseBranch
        self.isPullRequestMerged = isPullRequestMerged
        self.isAgentMidTurn = isAgentMidTurn
        self.hasOperationInProgress = hasOperationInProgress
        self.takenBranches = takenBranches
    }
}

public enum ContinuationRefusal: Sendable, Hashable {
    case notMerged
    case agentMidTurn
    case detachedHead
    case switchedByHand(onBranch: String, pullRequestBranch: String)
    case operationInProgress
    case onBaseBranch(String)
    case noValidName

    public var sentence: String {
        switch self {
        case .notMerged:
            "Continue is for a workspace whose pull request has landed. This one has not."
        case .agentMidTurn:
            "An agent is mid turn in this workspace, working or waiting for permission. Continuing "
                + "would move the branch under it. Let the turn finish, then press Continue again."
        case .detachedHead:
            "This worktree is not on a branch at all. Commits made on a detached HEAD are held by "
                + "nothing but this checkout, so Unified Dev will not move it."
        case .switchedByHand(let branch, let pullRequestBranch):
            "This worktree is on \(branch) now, and the pull request that merged was for "
                + "\(pullRequestBranch). Unified Dev will not move a checkout off a branch it was not "
                + "the one to put it on."
        case .operationInProgress:
            "A rebase or merge is half finished in this worktree. Finish or abort it first."
        case .onBaseBranch(let branch):
            "This worktree is on \(branch), which is the branch everything is merged into. "
                + "There is nothing to continue from here."
        case .noValidName:
            "Unified Dev could not work out a branch name to continue on."
        }
    }
}

public enum ContinuationDecision: Sendable, Hashable {
    case cut(branch: String)
    case refuse(ContinuationRefusal)

    public var branch: String? {
        if case .cut(let branch) = self { return branch }
        return nil
    }

    public var refusal: ContinuationRefusal? {
        if case .refuse(let refusal) = self { return refusal }
        return nil
    }
}

public enum ContinuationHead {
    public static func branch(
        of pullRequest: PullRequest, recorded: String, checkedOut: String?, base: String
    ) -> String {
        let reported = pullRequest.branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard reported.isEmpty else { return reported }
        return PullRequestHead.branch(recorded: recorded, checkedOut: checkedOut, base: base)
    }
}

public enum ContinuationGate {
    public static func decide(_ facts: ContinuationFacts) -> ContinuationDecision {
        guard facts.isPullRequestMerged else { return .refuse(.notMerged) }

        guard !facts.isAgentMidTurn else { return .refuse(.agentMidTurn) }

        guard let checkedOut = facts.checkedOutBranch else { return .refuse(.detachedHead) }
        guard checkedOut != facts.baseBranch else {
            return .refuse(.onBaseBranch(checkedOut))
        }
        guard checkedOut == facts.mergedBranch else {
            return .refuse(
                .switchedByHand(onBranch: checkedOut, pullRequestBranch: facts.mergedBranch)
            )
        }

        guard !facts.hasOperationInProgress else { return .refuse(.operationInProgress) }

        let branch = ContinuationBranch.next(after: checkedOut, taken: facts.takenBranches)
        guard Git.isValidBranchName(branch), !facts.takenBranches.contains(branch) else {
            return .refuse(.noValidName)
        }
        return .cut(branch: branch)
    }
}

public enum ContinuationBranch {
    public static func next(after branch: String, taken: Set<String>) -> String {
        Git.uniqueBranch(stem(of: branch, taken: taken), taken: taken)
    }

    static func stem(of branch: String, taken: Set<String>) -> String {
        guard let separator = branch.lastIndex(of: "-") else { return branch }
        let suffix = branch[branch.index(after: separator)...]
        guard !suffix.isEmpty, suffix.allSatisfy(\.isNumber) else { return branch }

        let stem = String(branch[branch.startIndex..<separator])
        guard !stem.isEmpty, taken.contains(stem) else { return branch }
        return stem
    }
}

public enum ContinuationBase: String, Sendable, Hashable {
    case fetched
    case cachedRemote
    case localBranch
}

public struct WorkspaceContinuation: Sendable, Hashable {
    public var workspace: Workspace
    public var previousBranch: String
    public var branch: String
    public var revision: String
    public var base: ContinuationBase

    public init(
        workspace: Workspace,
        previousBranch: String,
        branch: String,
        revision: String,
        base: ContinuationBase
    ) {
        self.workspace = workspace
        self.previousBranch = previousBranch
        self.branch = branch
        self.revision = revision
        self.base = base
    }

    public func promptValues(pullRequest: Int) -> [String: String] {
        [
            PromptRegistry.ContinueAfterMerge.workspace: workspace.name,
            PromptRegistry.ContinueAfterMerge.branch: branch,
            PromptRegistry.ContinueAfterMerge.previousBranch: previousBranch,
            PromptRegistry.ContinueAfterMerge.baseBranch: workspace.baseBranch,
            PromptRegistry.ContinueAfterMerge.pullRequest: String(pullRequest),
        ]
    }

    public func render(template: String, pullRequest: Int) -> PromptRender {
        PromptTemplate.render(template, values: promptValues(pullRequest: pullRequest))
    }
}

public struct ContinuedBranch: Sendable, Hashable {
    public var branch: String
    public var previousBranch: String
    public var baseBranch: String
    public var pullRequest: Int

    public init(branch: String, previousBranch: String, baseBranch: String, pullRequest: Int) {
        self.branch = branch
        self.previousBranch = previousBranch
        self.baseBranch = baseBranch
        self.pullRequest = pullRequest
    }

    public init(_ continuation: WorkspaceContinuation, pullRequest: Int) {
        self.init(
            branch: continuation.branch,
            previousBranch: continuation.previousBranch,
            baseBranch: continuation.workspace.baseBranch,
            pullRequest: pullRequest
        )
    }

    public static func line(on branch: String, continued: ContinuedBranch?) -> String {
        guard let continued, continued.branch == branch else {
            return "Nothing has changed on this branch yet."
        }
        let merged = continued.pullRequest > 0
            ? "#\(continued.pullRequest)"
            : continued.previousBranch
        return "Cut from \(continued.baseBranch) after \(merged) merged. Nothing on it yet."
    }
}

public extension WorkspaceManager {
    func continuationFacts(
        workspace: Workspace,
        pullRequest: PullRequest?,
        isAgentMidTurn: Bool
    ) async throws -> ContinuationFacts {
        async let checkedOut = try? Git.currentBranch(of: workspace.path)
        async let inProgress = Git.hasOperationInProgress(in: workspace.path)
        async let branches = try? Git.branches(of: workspace.path)

        let live = await checkedOut
        let merged = pullRequest.map {
            ContinuationHead.branch(
                of: $0, recorded: workspace.branch, checkedOut: live, base: workspace.baseBranch
            )
        }

        return ContinuationFacts(
            mergedBranch: merged ?? workspace.branch,
            checkedOutBranch: live,
            baseBranch: workspace.baseBranch,
            isPullRequestMerged: pullRequest?.isMerged ?? false,
            isAgentMidTurn: isAgentMidTurn,
            hasOperationInProgress: await inProgress,
            takenBranches: Set(await branches ?? [])
        )
    }

    func continueOnNewBranch(
        workspace: Workspace,
        branch: String
    ) async throws -> WorkspaceContinuation {
        let leaving = (try? await Git.currentBranch(of: workspace.path)) ?? workspace.branch
        let resolved = try await Git.baseRevision(
            branch: workspace.baseBranch, in: workspace.path
        )

        let context = try await Git.repositoryContext(in: workspace.path, baseBranch: workspace.baseBranch)
        try await Git.checkoutNewBranch(branch, at: resolved.revision, in: workspace.path)
        try await Git.recordBase(context, for: branch, in: workspace.path)

        let updated = try await store.update(workspaceID: workspace.id) {
            $0.branch = branch
            $0.pullRequestNumber = nil
        }
        guard let saved = updated else { throw WorkspaceError.workspaceGone(workspace.name) }
        return WorkspaceContinuation(
            workspace: saved,
            previousBranch: leaving,
            branch: branch,
            revision: resolved.revision,
            base: resolved.base
        )
    }
}
