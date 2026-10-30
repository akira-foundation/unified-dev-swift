import Foundation

public struct QuotaAccountOffer: Equatable, Sendable {
    enum Trouble: Equatable, Sendable {
        case allowanceSpent(resetsAt: Date?)
        case signedOut(AgentAccountSignOut.Cause)
    }

    public struct Choice: Equatable, Sendable, Identifiable {
        public let home: AgentAccountHome
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
        let choices = candidates.filter { $0.standing.cliReport != .claimsNoSession }.map {
            choice(for: $0.standing, plan: $0.plan, among: input.standings)
        }
        if case .allowanceSpent = trouble, choices.isEmpty { return nil }

        return QuotaAccountOffer(
            headline: headline(for: trouble, in: input),
            choices: choices,
            notes: notes(candidates: candidates, choices: choices, in: input)
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
        let target = AgentAccountNames.reference(to: standing, among: standings)
        return Choice(
            home: standing.home,
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
        candidates: [(standing: AgentAccountStanding, plan: AgentAccountSwitch)],
        choices: [Choice],
        in input: Input
    ) -> [String] {
        var notes: [String] = []
        if choices.isEmpty {
            notes.append(AgentAccountSignOut.recovery(provider: input.session.agentKind))
        } else {
            notes.append(
                "Starts this turn's message again on that account, with its attached files if they are still "
                    + "where they were, and keeps the \(input.workspaceName) workspace on it until you choose "
                    + "another account for it. The agent starts without this conversation's history. "
                    + "The transcript here stays."
            )
            notes.append(
                "Unified Dev cannot tell whether an account has allowance or a working sign-in until a turn "
                    + "runs on it. A sign-in the CLI cannot refresh is removed, and the account then needs "
                    + "signing in again."
            )
        }
        notes += doubts(about: choices, in: candidates, among: input.standings)
        notes += signedOutNote(in: candidates, among: input.standings)
        return notes
    }

    static func doubts(
        about choices: [Choice],
        in candidates: [(standing: AgentAccountStanding, plan: AgentAccountSwitch)],
        among standings: [AgentAccountStanding]
    ) -> [String] {
        let offered = Set(choices.map(\.id))
        return candidates.map(\.standing).compactMap { standing in
            guard offered.contains(standing.home.id), !standing.home.isDefault,
                  let doubt = standing.isolationDoubt else { return nil }
            return "\(AgentAccountNames.title(of: standing, among: standings)): \(doubt)"
        }
    }

    static func signedOutNote(
        in candidates: [(standing: AgentAccountStanding, plan: AgentAccountSwitch)],
        among standings: [AgentAccountStanding]
    ) -> [String] {
        let names = candidates.map(\.standing).filter { $0.cliReport == .claimsNoSession }
            .map { AgentAccountNames.title(of: $0, among: standings) }
        guard !names.isEmpty else { return [] }
        let verb = names.count == 1 ? "is signed out, so it is" : "are signed out, so they are"
        return ["\(names.joined(separator: " and ")) \(verb) not offered."]
    }
}
