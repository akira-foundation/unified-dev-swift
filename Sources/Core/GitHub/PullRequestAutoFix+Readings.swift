import Foundation

public extension PullRequestAutoFix {
    struct ChatReading: Sendable, Hashable {
        public var runsInTerminal: Bool
        public var isBusy: Bool
        public var isAwaitingAnswer: Bool
        public var wasStoppedByOwner: Bool
        public var skipsPermissions: Bool

        public init(
            runsInTerminal: Bool,
            isBusy: Bool,
            isAwaitingAnswer: Bool,
            wasStoppedByOwner: Bool,
            skipsPermissions: Bool
        ) {
            self.runsInTerminal = runsInTerminal
            self.isBusy = isBusy
            self.isAwaitingAnswer = isAwaitingAnswer
            self.wasStoppedByOwner = wasStoppedByOwner
            self.skipsPermissions = skipsPermissions
        }
    }

    static func chat(_ reading: ChatReading?) -> Chat {
        guard let reading else { return .absent }
        if reading.runsInTerminal { return .terminal }
        if reading.isAwaitingAnswer { return .awaitingAnswer }
        if reading.isBusy || reading.wasStoppedByOwner { return .busy }
        return reading.skipsPermissions ? .unattended : .ready
    }

    static func account(
        isResolved: Bool, provider: AgentKind, quotas: [AgentQuota], at now: Date
    ) -> Account {
        guard isResolved else { return .missing }
        let isSpent = quotas.contains { quota in
            guard quota.provider == provider, let used = quota.fraction else { return false }
            return UsageMeterReading.isSpent(used: used, limit: 1, money: false)
                && (quota.resetsAt.map { $0 > now } ?? true)
        }
        return isSpent ? .quotaExhausted : .usable
    }

    static func isWorthReading(_ pullRequest: PullRequest, ledger: Ledger) -> Bool {
        guard pullRequest.isOpen else { return false }
        if pullRequest.hasConflicts || pullRequest.checks == .failing { return true }
        return pullRequest.checks == .passing && ledger.inARow > 0
    }

    static func stoppedSentence(number: Int) -> String {
        "Stopped asking the agent to fix #\(number) after \(attemptsInARow) attempts in a row."
    }
}
