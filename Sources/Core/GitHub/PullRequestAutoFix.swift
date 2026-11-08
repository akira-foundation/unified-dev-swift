import Foundation

public enum PullRequestAutoFix {
    public static let attemptsInARow = 3

    public enum Reason: String, Sendable, Hashable, CaseIterable {
        case conflicts
        case checks
    }

    public struct Attempt: Sendable, Hashable {
        public let headCommit: String
        public let reason: Reason

        public init(headCommit: String, reason: Reason) {
            self.headCommit = headCommit
            self.reason = reason
        }
    }

    public struct Ledger: Sendable, Hashable {
        public var inARow: Int
        public var tried: Set<Attempt>
        public var stopAnnounced: Bool

        public init(inARow: Int = 0, tried: Set<Attempt> = [], stopAnnounced: Bool = false) {
            self.inARow = inARow
            self.tried = tried
            self.stopAnnounced = stopAnnounced
        }
    }

    public enum Chat: Sendable, Hashable {
        case absent
        case terminal
        case busy
        case awaitingAnswer
        case ready
    }

    public enum Account: Sendable, Hashable {
        case usable
        case missing
        case quotaExhausted
    }

    public enum Leave: Sendable, Hashable {
        case switchedOff
        case notOpen
        case archived
        case notTheOwners
        case notThisBranch
        case nothingToFix
        case unknownHead
        case checksUnfinished
        case localWork
        case noChat
        case terminal
        case busy
        case awaitingAnswer
        case stopped
        case alreadyTried
        case noAccount
        case quotaExhausted
    }

    public enum Verdict: Sendable, Hashable {
        case send(Attempt)
        case forgiveRun
        case announceStop
        case leave(Leave)
    }

    public struct Situation: Sendable {
        public var isEnabled: Bool
        public var pullRequest: PullRequest
        public var localWork: LocalWork?
        public var workspaceBranch: String
        public var checkedOutBranch: String?
        public var viewerLogin: String?
        public var isArchived: Bool
        public var chat: Chat
        public var account: Account
        public var ledger: Ledger

        public init(
            isEnabled: Bool,
            pullRequest: PullRequest,
            localWork: LocalWork?,
            workspaceBranch: String,
            checkedOutBranch: String?,
            viewerLogin: String?,
            isArchived: Bool,
            chat: Chat,
            account: Account,
            ledger: Ledger
        ) {
            self.isEnabled = isEnabled
            self.pullRequest = pullRequest
            self.localWork = localWork
            self.workspaceBranch = workspaceBranch
            self.checkedOutBranch = checkedOutBranch
            self.viewerLogin = viewerLogin
            self.isArchived = isArchived
            self.chat = chat
            self.account = account
            self.ledger = ledger
        }
    }

    public static func decide(_ situation: Situation) -> Verdict {
        let pullRequest = situation.pullRequest
        guard situation.isEnabled else { return .leave(.switchedOff) }
        guard pullRequest.isOpen else { return .leave(.notOpen) }
        guard !situation.isArchived else { return .leave(.archived) }
        guard isTheOwners(pullRequest, viewerLogin: situation.viewerLogin) else { return .leave(.notTheOwners) }
        guard isOnWorkspaceBranch(situation) else { return .leave(.notThisBranch) }

        if isSettled(pullRequest), situation.ledger.inARow > 0 { return .forgiveRun }

        guard let reason = reason(pullRequest, localWork: situation.localWork) else { return .leave(.nothingToFix) }
        guard let head = pullRequest.headCommit, !head.isEmpty else { return .leave(.unknownHead) }
        guard pullRequest.hasUnfinishedChecks == false else { return .leave(.checksUnfinished) }
        guard let local = situation.localWork, !local.isAhead else { return .leave(.localWork) }
        if let held = held(by: situation.chat) { return .leave(held) }

        if situation.ledger.inARow >= attemptsInARow {
            return situation.ledger.stopAnnounced ? .leave(.stopped) : .announceStop
        }
        let attempt = Attempt(headCommit: head, reason: reason)
        guard !situation.ledger.tried.contains(attempt) else { return .leave(.alreadyTried) }

        switch situation.account {
        case .usable: return .send(attempt)
        case .missing: return .leave(.noAccount)
        case .quotaExhausted: return .leave(.quotaExhausted)
        }
    }

    private static func isTheOwners(_ pullRequest: PullRequest, viewerLogin: String?) -> Bool {
        guard pullRequest.isFromFork == false,
              let author = pullRequest.author, !author.isEmpty,
              let viewerLogin, !viewerLogin.isEmpty
        else { return false }
        return author.caseInsensitiveCompare(viewerLogin) == .orderedSame
    }

    private static func isOnWorkspaceBranch(_ situation: Situation) -> Bool {
        situation.pullRequest.branch == situation.workspaceBranch
            && situation.checkedOutBranch == situation.workspaceBranch
    }

    private static func isSettled(_ pullRequest: PullRequest) -> Bool {
        pullRequest.checks == .passing && !pullRequest.hasConflicts && !pullRequest.isMergeabilityUnknown
    }

    private static func reason(_ pullRequest: PullRequest, localWork: LocalWork?) -> Reason? {
        let status = pullRequest.status(local: localWork)
        switch PullRequestStanding.act(for: status.remedy, checks: pullRequest.checks) {
        case .askToFixConflicts: return .conflicts
        case .askToFixChecks: return .checks
        default: return nil
        }
    }

    private static func held(by chat: Chat) -> Leave? {
        switch chat {
        case .absent: .noChat
        case .terminal: .terminal
        case .busy: .busy
        case .awaitingAnswer: .awaitingAnswer
        case .ready: nil
        }
    }
}
