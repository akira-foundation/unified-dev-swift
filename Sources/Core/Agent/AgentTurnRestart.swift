import Foundation

public struct AgentTurnRestart: Sendable, Equatable {
    public enum Step: Sendable, Equatable {
        case stopTurn
        case waitForTurnToSettle
        case chooseAccount
        case retireRunner
        case submit
    }

    public enum Resolution: Sendable, Equatable {
        case resolved(AgentAccountHome?)
        case failed(String)
    }

    public struct Input: Sendable {
        public var isWorkspaceArchiving: Bool
        public var session: Session
        public var resolution: Resolution
        public var target: AgentAccountHome
        public var isTurnInFlight: Bool
        public var turnPrompt: String?
        public var lastUserText: String?
        public var isRecordedAccountPresent: Bool

        public init(
            isWorkspaceArchiving: Bool,
            session: Session,
            resolution: Resolution,
            target: AgentAccountHome,
            isTurnInFlight: Bool,
            turnPrompt: String?,
            lastUserText: String?,
            isRecordedAccountPresent: Bool
        ) {
            self.isWorkspaceArchiving = isWorkspaceArchiving
            self.session = session
            self.resolution = resolution
            self.target = target
            self.isTurnInFlight = isTurnInFlight
            self.turnPrompt = turnPrompt
            self.lastUserText = lastUserText
            self.isRecordedAccountPresent = isRecordedAccountPresent
        }
    }

    public struct Refused: Error, Sendable, Equatable {
        public let sentence: String
    }

    public let steps: [Step]
    public let destination: AgentAccountHome
    public let prompt: String
    public let notice: String?

    public static let workspaceArchiving = "The workspace is being archived."
    public static let turnDidNotStop = "The running turn did not stop in time, so the account was not changed."
    public static let notRestarted = "Unified Dev could not start the message again."

    public static func decide(_ input: Input) -> Result<AgentTurnRestart, Refused> {
        let session = input.session
        let provider = session.agentKind
        if input.isWorkspaceArchiving { return refused(workspaceArchiving) }
        let from: AgentAccountHome
        switch input.resolution {
        case .failed(let detail):
            return refused("Unified Dev could not work out which account this chat runs under: \(detail)")
        case .resolved(nil):
            return refused("\(provider.label) has no separate accounts.")
        case .resolved(let home?):
            from = home
        }
        let strandedOwner = session.accountID.flatMap { $0 == from.id ? nil : $0 }
        if strandedOwner != nil, input.isRecordedAccountPresent {
            return refused(
                "This chat's history belongs to a different account from the one it would run under, "
                    + "so Unified Dev did not move it."
            )
        }
        let plan = AgentAccountSwitch.plan(
            session: session, from: from, to: input.target, isTurnInFlight: input.isTurnInFlight
        )
        if plan.refusal != nil {
            return refused("\(input.target.provider.label) accounts cannot run a \(provider.label) chat.")
        }
        guard let destination = plan.destination(of: input.target) else {
            return refused("This chat already runs on that account.")
        }
        guard let prompt = prompt(for: input) else { return refused("This chat has no message to start again.") }
        var steps: [Step] = []
        if plan.losesTurnInFlight { steps += [.stopTurn, .waitForTurnToSettle] }
        steps += [.chooseAccount, .retireRunner, .submit]
        return .success(AgentTurnRestart(
            steps: steps,
            destination: destination,
            prompt: prompt,
            notice: strandedOwner == nil ? nil : strandedNotice(for: provider)
        ))
    }

    public static func isRecordedAccountPresent(
        of session: Session, in accounts: AgentAccountResolution?
    ) -> Bool {
        guard let recorded = session.accountID, let accounts else { return true }
        return accounts.isPresent(recorded)
    }

    public static func strandedNotice(for provider: AgentKind) -> String {
        "This chat's history belongs to a \(provider.label) account that is not on this Mac, "
            + "so moving it starts a new conversation under the account you chose. "
            + "The transcript here is unchanged."
    }

    static func prompt(for input: Input) -> String? {
        [input.turnPrompt, input.lastUserText]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func refused(_ sentence: String) -> Result<AgentTurnRestart, Refused> {
        .failure(Refused(sentence: sentence))
    }
}
