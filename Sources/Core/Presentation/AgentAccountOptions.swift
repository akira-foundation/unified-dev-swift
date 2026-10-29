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
        public let entries: [Entry]

        public var id: AgentKind { provider }
        public var title: String { provider.label }
    }

    public let inherit: Entry
    public let groups: [Group]
    public let unavailable: Entry?
    public let selected: Pick
    public let footer: String
    public let warns: Bool

    public func entry(for pick: Pick) -> Entry? {
        ([inherit] + groups.flatMap(\.entries) + [unavailable].compactMap { $0 }).first { $0.pick == pick }
    }

    public static func make(
        scope: Scope,
        workspace: AgentAccountID?,
        project: AgentAccountID?,
        standings: [AgentAccountStanding]
    ) -> AgentAccountOptions {
        let stored = scope == .project ? project : workspace
        let inherited = project
        let present = standings.filter { $0.directoryExists || $0.home.isDefault }
        let offered = present.filter { scope == .workspace || !$0.home.isDefault || $0.home.id == stored }
        let groups = AgentKind.allCases.compactMap { provider -> Group? in
            let entries = offered.filter { $0.home.provider == provider }.map {
                Entry(pick: .account($0.home.id), title: AgentAccountNames.title(of: $0, among: standings), home: $0.home)
            }
            return entries.isEmpty ? nil : Group(provider: provider, entries: entries)
        }

        let storedStanding = stored.flatMap { id in present.first { $0.home.id == id } }
        let inheritedStanding = inherited.flatMap { id in present.first { $0.home.id == id } }
        let isUnavailable = stored != nil && storedStanding == nil

        let selected: Pick = switch (storedStanding, isUnavailable) {
        case (let found?, _): .account(found.home.id)
        case (nil, true): .unavailable
        case (nil, false): .inherit
        }
        let words = footer(
            scope: scope,
            own: storedStanding,
            ownIsUnavailable: isUnavailable,
            inherited: inheritedStanding,
            inheritedIsUnavailable: inherited != nil && inheritedStanding == nil,
            standings: standings
        )

        return AgentAccountOptions(
            inherit: Entry(pick: .inherit, title: scope == .project ? "Default accounts" : "Same as project", home: nil),
            groups: groups,
            unavailable: isUnavailable ? Entry(pick: .unavailable, title: "Unavailable account", home: nil) : nil,
            selected: selected,
            footer: words.text,
            warns: words.warns
        )
    }

    private static func footer(
        scope: Scope,
        own: AgentAccountStanding?,
        ownIsUnavailable: Bool,
        inherited: AgentAccountStanding?,
        inheritedIsUnavailable: Bool,
        standings: [AgentAccountStanding]
    ) -> (text: String, warns: Bool) {
        switch scope {
        case .project:
            if let own { return (runs(own, "\(phrase(own, standings)) in this project."), false) }
            if ownIsUnavailable {
                return ("The account chosen for this project is no longer on this Mac, so agents run their default accounts.", true)
            }
            return ("Agents in this project run their default accounts unless a workspace chooses its own.", false)
        case .workspace:
            if let own { return (runs(own, "\(phrase(own, standings)) in this workspace."), false) }
            if ownIsUnavailable {
                let tail = inheritedIsUnavailable
                    ? " The project's choice is gone too, so agents run their default accounts."
                    : " It follows the project instead."
                return ("The account chosen for this workspace is no longer on this Mac." + tail, true)
            }
            if let inherited {
                return (runs(inherited, "Follows the project, so \(phrase(inherited, standings)) here."), false)
            }
            if inheritedIsUnavailable {
                return ("The account chosen for the project is no longer on this Mac, so agents run their default accounts.", true)
            }
            return ("Follows the project, which has no account of its own, so agents run their default accounts.", false)
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
