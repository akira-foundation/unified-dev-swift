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
        let isLost = choice.isProjectChoiceLost
        let agent = provider.label

        guard let home = choice.home else {
            let sentence = "\(agent) has no separate accounts, so it runs with its own login."
            guard isLost else { return AgentAccountLine(title: nil, sentence: sentence, warns: false) }
            return AgentAccountLine(
                title: unavailableTitle,
                sentence: "\(sentence) \(because(agent: agent, leading: "However, ")).",
                warns: true
            )
        }
        let name = AgentAccountNames.title(of: home, among: standings) ?? home.directory.lastPathComponent

        let isGeneric = AgentAccountNames.isGenericDefault(home, among: standings)
        let subject = isGeneric ? "The default account" : name
        let base: String = switch choice.reason {
        case .project:
            "\(subject) runs here, chosen for the project."
        case .providerDefault where !isLost:
            "\(subject) runs here\(defaultAppositive(isGeneric))."
        case .providerDefault, .noAccount:
            "\(subject) runs here\(defaultAppositive(isGeneric)), \(because(agent: agent))."
        }

        return AgentAccountLine(
            title: name,
            sentence: base + doubt(for: home, in: standings),
            warns: isLost
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

    private static func because(agent: String, leading: String = "because ") -> String {
        "\(leading)the account chosen for the project is not available for \(agent)"
    }
}
