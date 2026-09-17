import Foundation

public struct BranchRenameFacts: Sendable, Hashable {
    public var recordedBranch: String
    public var checkedOutBranch: String?
    public var desiredBranch: String
    public var commitsAhead: Int
    public var hasUpstream: Bool
    public var hasRemoteCounterpart: Bool
    public var hasPullRequest: Bool
    public var hasOperationInProgress: Bool
    public var takenBranches: Set<String>

    public init(
        recordedBranch: String,
        checkedOutBranch: String?,
        desiredBranch: String,
        commitsAhead: Int = 0,
        hasUpstream: Bool = false,
        hasRemoteCounterpart: Bool = false,
        hasPullRequest: Bool = false,
        hasOperationInProgress: Bool = false,
        takenBranches: Set<String> = []
    ) {
        self.recordedBranch = recordedBranch
        self.checkedOutBranch = checkedOutBranch
        self.desiredBranch = desiredBranch
        self.commitsAhead = commitsAhead
        self.hasUpstream = hasUpstream
        self.hasRemoteCounterpart = hasRemoteCounterpart
        self.hasPullRequest = hasPullRequest
        self.hasOperationInProgress = hasOperationInProgress
        self.takenBranches = takenBranches
    }
}

public enum BranchRenameRefusal: Sendable, Hashable {
    case alreadyNamed
    case noValidName
    case hasCommits(Int)
    case pushed
    case hasPullRequest
    case renamedByHand(String)
    case detachedHead
    case operationInProgress
    case nameTaken(String)
    case gitRefused(String)

    public var reason: String {
        switch self {
        case .alreadyNamed:
            "it already has the name Unified Dev would have given it"
        case .noValidName:
            "the model did not come back with a branch name git would accept"
        case .hasCommits(let count):
            "it already has \(count) commit\(count == 1 ? "" : "s") on it"
        case .pushed:
            "it has already been pushed, and renaming it here would leave the pushed one behind"
        case .hasPullRequest:
            "it has a pull request open against it"
        case .renamedByHand(let branch):
            "you are on `\(branch)` now, which is not the branch Unified Dev created"
        case .detachedHead:
            "this worktree is not on a branch at all"
        case .operationInProgress:
            "a rebase or merge is half finished in this worktree"
        case .nameTaken(let branch):
            "`\(branch)` is already taken by another branch"
        case .gitRefused(let message):
            "git refused to rename it: `\(message)`"
        }
    }

    public var isWorthReporting: Bool {
        switch self {
        case .alreadyNamed, .noValidName: false
        default: true
        }
    }
}

public enum BranchRenameDecision: Sendable, Hashable {
    case rename(to: String)
    case refuse(BranchRenameRefusal)

    public var refusal: BranchRenameRefusal? {
        if case .refuse(let refusal) = self { return refusal }
        return nil
    }
}

public enum BranchRenameGate {
    public static func decide(_ facts: BranchRenameFacts) -> BranchRenameDecision {
        let desired = facts.desiredBranch.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !desired.isEmpty, Git.isValidBranchName(desired) else {
            return .refuse(.noValidName)
        }
        guard desired != facts.recordedBranch else {
            return .refuse(.alreadyNamed)
        }

        guard let checkedOut = facts.checkedOutBranch else {
            return .refuse(.detachedHead)
        }
        guard checkedOut == facts.recordedBranch else {
            return .refuse(.renamedByHand(checkedOut))
        }

        if facts.hasPullRequest { return .refuse(.hasPullRequest) }
        if facts.hasUpstream || facts.hasRemoteCounterpart { return .refuse(.pushed) }

        if facts.hasOperationInProgress { return .refuse(.operationInProgress) }
        if facts.commitsAhead > 0 { return .refuse(.hasCommits(facts.commitsAhead)) }

        if facts.takenBranches.contains(desired) {
            return .refuse(.nameTaken(desired))
        }

        return .rename(to: desired)
    }
}
