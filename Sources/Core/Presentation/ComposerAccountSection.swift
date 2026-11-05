import Foundation

public struct ComposerAccountSection: Sendable, Equatable {
    public static let heading = "Account"
    public static let change = "Change\u{2026}"

    public let title: String
    public let sentence: String
    public let warns: Bool
    public let repoID: RepoID

    public static func make(
        repoID: RepoID?,
        provider: AgentKind,
        choice: AgentAccountChoice,
        standings: [AgentAccountStanding]
    ) -> ComposerAccountSection? {
        guard let repoID else { return nil }
        let line = AgentAccountLine.make(choice: choice, provider: provider, standings: standings)
        let accounts = AgentAccountChoice.present(in: standings).filter { $0.provider == provider }
        guard line.warns || accounts.count > 1 else { return nil }
        return ComposerAccountSection(
            title: line.title ?? AgentAccountLine.unavailableTitle,
            sentence: line.sentence,
            warns: line.warns,
            repoID: repoID
        )
    }
}
