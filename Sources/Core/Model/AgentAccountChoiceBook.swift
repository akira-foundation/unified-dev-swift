import Foundation

public struct AgentAccountChoices: Sendable, Hashable {
    public let project: [AgentKind: AgentAccountID]

    public static let none = AgentAccountChoices()

    public init(project: [AgentKind: AgentAccountID] = [:]) {
        self.project = project
    }
}

public struct AgentAccountChoiceBook: Sendable, Hashable {
    public var repos: [RepoID: [AgentKind: AgentAccountID]]

    public init(repos: [RepoID: [AgentKind: AgentAccountID]] = [:]) {
        self.repos = repos
    }

    public func choices(repoID: RepoID?) -> AgentAccountChoices {
        AgentAccountChoices(project: repoID.flatMap { repos[$0] } ?? [:])
    }

    public mutating func record(
        _ account: AgentAccountID,
        of provider: AgentKind,
        forRepo id: RepoID
    ) {
        repos[id, default: [:]][provider] = account
    }
}
