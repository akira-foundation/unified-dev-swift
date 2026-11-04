import Foundation

public struct AgentAccountLine: Sendable, Equatable {
    public static let unavailableTitle = "Account unavailable"

    public let title: String?
    public let sentence: String
    public let warns: Bool

    public init(title: String?, sentence: String, warns: Bool) {
        self.title = title
        self.sentence = sentence
        self.warns = warns
    }

    public static func make(
        choice: AgentAccountChoice,
        provider: AgentKind,
        standings: [AgentAccountStanding]
    ) -> AgentAccountLine {
        let lost = choice.lost
        let agent = provider.label

        guard let home = choice.home else {
            let sentence = "\(agent) has no separate accounts, so it runs with its own login."
            guard !lost.isEmpty else { return AgentAccountLine(title: nil, sentence: sentence, warns: false) }
            return AgentAccountLine(
                title: unavailableTitle,
                sentence: "\(sentence) \(because(lost, agent: agent, leading: "However, ")).",
                warns: true
            )
        }
        let name = AgentAccountNames.title(of: home, among: standings) ?? home.directory.lastPathComponent

        let isGeneric = AgentAccountNames.isGenericDefault(home, among: standings)
        let subject = isGeneric ? "The default account" : name
        let base: String = switch choice.reason {
        case .workspace:
            "\(subject) runs here, chosen for this workspace."
        case .project where lost.contains(.workspace):
            "\(subject) runs here, the project's account, \(because(lost, agent: agent))."
        case .project:
            "\(subject) runs here, chosen for the project."
        case .providerDefault where lost.isEmpty:
            "\(subject) runs here\(defaultAppositive(isGeneric))."
        case .providerDefault, .noAccount:
            "\(subject) runs here\(defaultAppositive(isGeneric)), \(because(lost, agent: agent))."
        }

        return AgentAccountLine(
            title: name,
            sentence: base + doubt(for: home, in: standings),
            warns: !lost.isEmpty
        )
    }

    private static func defaultAppositive(_ isGeneric: Bool) -> String {
        isGeneric ? "" : ", the default account"
    }

    private static func doubt(for home: AgentAccountHome, in standings: [AgentAccountStanding]) -> String {
        guard !home.isDefault,
              let standing = standings.first(where: { $0.home.id == home.id && $0.home.provider == home.provider }),
              let doubt = standing.isolationDoubt
        else { return "" }
        return " \(doubt)"
    }

    private static func because(
        _ lost: Set<AgentAccountChoice.Level>,
        agent: String,
        leading: String = "because "
    ) -> String {
        switch (lost.contains(.workspace), lost.contains(.project)) {
        case (true, true):
            "\(leading)the accounts chosen for this workspace and for the project are not available for \(agent)"
        case (true, false):
            "\(leading)the account chosen for this workspace is not available for \(agent)"
        default:
            "\(leading)the account chosen for the project is not available for \(agent)"
        }
    }
}
