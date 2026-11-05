import Foundation

public struct AgentAccountOptions: Sendable, Equatable {
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
        choices: AgentAccountChoices,
        standings: [AgentAccountStanding]
    ) -> AgentAccountOptions {
        let present = standings.filter { $0.directoryExists || $0.home.isDefault }
        let groups = AgentKind.allCases.compactMap { provider in
            group(provider: provider, stored: choices.project[provider], present: present, standings: standings)
        }
        return AgentAccountOptions(
            groups: groups,
            footer: groups.isEmpty ? "Every workspace and chat in this project runs each agent's default account." : nil
        )
    }

    private static func group(
        provider: AgentKind,
        stored: AgentAccountID?,
        present: [AgentAccountStanding],
        standings: [AgentAccountStanding]
    ) -> Group? {
        let mine = present.filter { $0.home.provider == provider }
        let offered = mine.filter { !$0.home.isDefault || $0.home.id == stored }
        guard !offered.isEmpty || stored != nil else { return nil }

        let storedStanding = stored.flatMap { id in mine.first { $0.home.id == id } }
        let isUnavailable = stored != nil && storedStanding == nil
        let selected: Pick = switch (storedStanding, isUnavailable) {
        case (let found?, _): .account(found.home.id)
        case (nil, true): .unavailable
        case (nil, false): .inherit
        }
        let words = note(provider: provider, own: storedStanding, ownIsUnavailable: isUnavailable, standings: standings)

        return Group(
            provider: provider,
            inherit: Entry(pick: .inherit, title: "Default account", home: nil),
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

    private static func note(
        provider: AgentKind,
        own: AgentAccountStanding?,
        ownIsUnavailable: Bool,
        standings: [AgentAccountStanding]
    ) -> (text: String, warns: Bool) {
        let agent = provider.label
        if let own {
            let sentence = "Every workspace and chat in this project runs \(agent) on "
                + "\(AgentAccountNames.reference(to: own, among: standings))."
            guard !own.home.isDefault, let doubt = own.isolationDoubt else { return (sentence, false) }
            return ("\(sentence) \(doubt)", false)
        }
        if ownIsUnavailable {
            return (
                "The account chosen for \(agent) in this project is no longer on this Mac, "
                    + "so every workspace and chat runs its default account.",
                true
            )
        }
        return ("Every workspace and chat in this project runs the default \(agent) account.", false)
    }
}
