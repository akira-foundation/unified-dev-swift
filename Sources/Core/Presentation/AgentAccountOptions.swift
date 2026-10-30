import Foundation

public struct AgentAccountOptions: Sendable, Equatable {
    public enum Scope: Sendable, Hashable {
        case project
        case workspace
    }

    public enum Pick: Sendable, Hashable {
        case inherit
        case unavailable
        case account(AgentAccountID)
    }

    public struct Entry: Sendable, Equatable, Identifiable {
        public let pick: Pick
        public let title: String
        public let home: AgentAccountHome?

        public var id: Pick { pick }
    }

    public struct Group: Sendable, Equatable, Identifiable {
        public let provider: AgentKind
        public let inherit: Entry
        public let entries: [Entry]
        public let unavailable: Entry?
        public let selected: Pick
        public let note: String
        public let warns: Bool

        public var id: AgentKind { provider }
        public var title: String { provider.label }

        public func chosen(for pick: Pick) -> ChosenAgentAccount? {
            switch pick {
            case .inherit:
                return ChosenAgentAccount(inheritedBy: provider)
            case .unavailable:
                return nil
            case .account:
                guard let home = entries.first(where: { $0.pick == pick })?.home else { return nil }
                return ChosenAgentAccount(home)
            }
        }
    }

    public let groups: [Group]
    public let footer: String?

    public static func make(
        scope: Scope,
        choices: AgentAccountChoices,
        standings: [AgentAccountStanding]
    ) -> AgentAccountOptions {
        let present = standings.filter { $0.directoryExists || $0.home.isDefault }
        let groups = AgentKind.allCases.compactMap { provider in
            group(
                scope: scope,
                provider: provider,
                stored: scope == .project ? choices.project[provider] : choices.workspace[provider],
                inherited: choices.project[provider],
                present: present,
                standings: standings
            )
        }
        return AgentAccountOptions(
            groups: groups,
            footer: groups.isEmpty ? nothingToOffer(scope) : nil
        )
    }

    private static func group(
        scope: Scope,
        provider: AgentKind,
        stored: AgentAccountID?,
        inherited: AgentAccountID?,
        present: [AgentAccountStanding],
        standings: [AgentAccountStanding]
    ) -> Group? {
        let mine = present.filter { $0.home.provider == provider }
        let offered = mine.filter { scope == .workspace || !$0.home.isDefault || $0.home.id == stored }
        guard !offered.isEmpty || stored != nil else { return nil }

        let storedStanding = stored.flatMap { id in mine.first { $0.home.id == id } }
        let inheritedStanding = inherited.flatMap { id in mine.first { $0.home.id == id } }
        let isUnavailable = stored != nil && storedStanding == nil
        let selected: Pick = switch (storedStanding, isUnavailable) {
        case (let found?, _): .account(found.home.id)
        case (nil, true): .unavailable
        case (nil, false): .inherit
        }
        let words = note(
            scope: scope,
            provider: provider,
            own: storedStanding,
            ownIsUnavailable: isUnavailable,
            inherited: inheritedStanding,
            inheritedIsUnavailable: inherited != nil && inheritedStanding == nil,
            standings: standings
        )

        return Group(
            provider: provider,
            inherit: Entry(
                pick: .inherit,
                title: scope == .project ? "Default account" : "Same as project",
                home: nil
            ),
            entries: offered.map {
                Entry(
                    pick: .account($0.home.id),
                    title: AgentAccountNames.title(of: $0, among: standings),
                    home: $0.home
                )
            },
            unavailable: isUnavailable ? Entry(pick: .unavailable, title: "Unavailable account", home: nil) : nil,
            selected: selected,
            note: words.text,
            warns: words.warns
        )
    }

    private static func nothingToOffer(_ scope: Scope) -> String {
        switch scope {
        case .project:
            "Agents in this project run their default accounts unless a workspace chooses its own."
        case .workspace:
            "Follows the project, which has no account of its own, so agents run their default accounts."
        }
    }

    private static func note(
        scope: Scope,
        provider: AgentKind,
        own: AgentAccountStanding?,
        ownIsUnavailable: Bool,
        inherited: AgentAccountStanding?,
        inheritedIsUnavailable: Bool,
        standings: [AgentAccountStanding]
    ) -> (text: String, warns: Bool) {
        let agent = provider.label
        switch scope {
        case .project:
            if let own { return (runs(own, "\(phrase(own, standings)) in this project."), false) }
            if ownIsUnavailable {
                return (
                    "The account chosen for \(agent) in this project is no longer on this Mac, "
                        + "so it runs its default account.",
                    true
                )
            }
            return ("\(agent) runs its default account unless a workspace chooses its own.", false)
        case .workspace:
            if let own { return (runs(own, "\(phrase(own, standings)) in this workspace."), false) }
            if ownIsUnavailable {
                let tail = inheritedIsUnavailable
                    ? " The project's choice is gone too, so it runs its default account."
                    : " It follows the project instead."
                return (
                    "The account chosen for \(agent) in this workspace is no longer on this Mac." + tail,
                    true
                )
            }
            if let inherited {
                return (runs(inherited, "Follows the project, so \(phrase(inherited, standings)) here."), false)
            }
            if inheritedIsUnavailable {
                return (
                    "The account chosen for \(agent) in the project is no longer on this Mac, "
                        + "so it runs its default account.",
                    true
                )
            }
            return ("Follows the project, which chose no \(agent) account, so it runs its default account.", false)
        }
    }

    private static func phrase(_ standing: AgentAccountStanding, _ standings: [AgentAccountStanding]) -> String {
        "\(standing.home.provider.label) runs \(AgentAccountNames.reference(to: standing, among: standings))"
    }

    private static func runs(
        _ standing: AgentAccountStanding,
        _ sentence: String
    ) -> String {
        guard !standing.home.isDefault, let doubt = standing.isolationDoubt else { return sentence }
        return "\(sentence) \(doubt)"
    }
}
