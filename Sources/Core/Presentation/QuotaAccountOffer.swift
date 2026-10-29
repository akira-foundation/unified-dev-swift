import Foundation

public struct QuotaAccountOffer: Equatable, Sendable {
    public enum Trouble: Equatable, Sendable {
        case allowanceSpent(resetsAt: Date?)
        case signedOut(AgentAccountSignOut.Cause)
    }

    public struct Choice: Equatable, Sendable, Identifiable {
        public let home: AgentAccountHome
        public let title: String
        public let button: String
        public let losesTurnInFlight: Bool

        public var id: AgentAccountID { home.id }
    }

    public struct Input: Sendable {
        public var session: Session
        public var current: AgentAccountHome
        public var standings: [AgentAccountStanding]
        public var notices: [MenuBarPanelContent.LimitNotice]
        public var signedOut: AgentAccountSignOut.Cause?
        public var isTurnInFlight: Bool
        public var workspaceName: String
        public var now: Date

        public init(
            session: Session,
            current: AgentAccountHome,
            standings: [AgentAccountStanding],
            notices: [MenuBarPanelContent.LimitNotice],
            signedOut: AgentAccountSignOut.Cause?,
            isTurnInFlight: Bool,
            workspaceName: String,
            now: Date
        ) {
            self.session = session
            self.current = current
            self.standings = standings
            self.notices = notices
            self.signedOut = signedOut
            self.isTurnInFlight = isTurnInFlight
            self.workspaceName = workspaceName
            self.now = now
        }
    }

    public let provider: AgentKind
    public let trouble: Trouble
    public let headline: String
    public let choices: [Choice]
    public let notes: [String]

    public static func make(_ input: Input) -> QuotaAccountOffer? {
        let provider = input.session.agentKind
        guard input.current.provider == provider,
              input.session.accountID == nil || input.session.accountID == input.current.id,
              let trouble = trouble(in: input)
        else { return nil }

        let candidates = input.standings
            .filter(\.directoryExists)
            .map { (standing: $0, plan: plan(to: $0.home, in: input)) }
            .filter(\.plan.relaunch)
        let signedOutOthers = candidates.map(\.standing).filter { $0.cliReport == .claimsNoSession }
        let choices = candidates.filter { $0.standing.cliReport != .claimsNoSession }.map {
            choice(for: $0.standing, plan: $0.plan, among: input.standings)
        }
        if case .allowanceSpent = trouble, choices.isEmpty { return nil }

        return QuotaAccountOffer(
            provider: provider,
            trouble: trouble,
            headline: headline(for: trouble, in: input),
            choices: choices,
            notes: notes(choices: choices, signedOutOthers: signedOutOthers, in: input)
        )
    }

    static func trouble(in input: Input) -> Trouble? {
        if let cause = input.signedOut { return .signedOut(cause) }
        let spent = input.notices.filter { $0.provider == input.session.agentKind }
        guard !spent.isEmpty else { return nil }
        let resets = spent.compactMap(\.resetsAt)
        return .allowanceSpent(resetsAt: resets.count == spent.count ? resets.max() : nil)
    }

    static func plan(to home: AgentAccountHome, in input: Input) -> AgentAccountSwitch {
        AgentAccountSwitch.plan(
            session: input.session, from: input.current, to: home, isTurnInFlight: input.isTurnInFlight
        )
    }

    static func choice(
        for standing: AgentAccountStanding,
        plan: AgentAccountSwitch,
        among standings: [AgentAccountStanding]
    ) -> Choice {
        let title = AgentAccountNames.title(of: standing, among: standings)
        let target = AgentAccountNames.reference(to: standing, among: standings)
        return Choice(
            home: standing.home,
            title: title,
            button: plan.losesTurnInFlight
                ? "Stop this turn and restart it on \(target)"
                : "Restart this turn on \(target)",
            losesTurnInFlight: plan.losesTurnInFlight
        )
    }

    static func subject(in input: Input) -> String {
        let named = input.standings.first { $0.home.id == input.current.id }
        guard let named else { return input.current.directory.lastPathComponent }
        return AgentAccountNames.isGenericDefault(named)
            ? "The default account"
            : AgentAccountNames.title(of: named, among: input.standings)
    }

    static func headline(for trouble: Trouble, in input: Input) -> String {
        let subject = subject(in: input)
        switch trouble {
        case .allowanceSpent(let resetsAt):
            guard let resetsAt else { return "\(subject) has no allowance left." }
            return "\(subject) has no allowance left. It resets \(QuotaCountdown.phrase(until: resetsAt, from: input.now))."
        case .signedOut(let cause):
            return AgentAccountSignOut.headline(cause, account: subject, provider: input.session.agentKind)
        }
    }

    static func notes(
        choices: [Choice],
        signedOutOthers: [AgentAccountStanding],
        in input: Input
    ) -> [String] {
        var notes: [String] = []
        if choices.isEmpty {
            notes.append(AgentAccountSignOut.recovery(provider: input.session.agentKind))
        } else {
            notes.append(
                "Starts your last message again on that account and keeps the "
                    + "\(input.workspaceName) workspace on it until you choose another account for it. "
                    + "The agent starts without this conversation's history. The transcript here stays."
            )
            notes.append(
                "Unified Dev cannot tell whether an account has allowance or a working sign-in until a turn "
                    + "runs on it. A sign-in the CLI cannot refresh is removed, and the account then needs "
                    + "signing in again."
            )
        }
        if !signedOutOthers.isEmpty {
            let names = signedOutOthers.map { AgentAccountNames.title(of: $0, among: input.standings) }
            notes.append("\(names.joined(separator: " and ")) is signed out, so it is not offered.")
        }
        return notes
    }
}
