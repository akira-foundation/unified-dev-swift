import Foundation

public struct AgentAccountChoices: Sendable, Hashable {
    public let workspace: [AgentKind: AgentAccountID]
    public let project: [AgentKind: AgentAccountID]

    public static let none = AgentAccountChoices()

    public init(
        workspace: [AgentKind: AgentAccountID] = [:],
        project: [AgentKind: AgentAccountID] = [:]
    ) {
        self.workspace = workspace
        self.project = project
    }
}

public struct AgentAccountChoiceBook: Sendable, Hashable {
    public var repos: [RepoID: [AgentKind: AgentAccountID]]
    public var workspaces: [WorkspaceID: [AgentKind: AgentAccountID]]

    public init(
        repos: [RepoID: [AgentKind: AgentAccountID]] = [:],
        workspaces: [WorkspaceID: [AgentKind: AgentAccountID]] = [:]
    ) {
        self.repos = repos
        self.workspaces = workspaces
    }

    public func choices(workspaceID: WorkspaceID?, repoID: RepoID?) -> AgentAccountChoices {
        AgentAccountChoices(
            workspace: workspaceID.flatMap { workspaces[$0] } ?? [:],
            project: repoID.flatMap { repos[$0] } ?? [:]
        )
    }

    public mutating func record(
        _ account: AgentAccountID,
        of provider: AgentKind,
        forRepo id: RepoID
    ) {
        repos[id, default: [:]][provider] = account
    }

    public mutating func record(
        _ account: AgentAccountID,
        of provider: AgentKind,
        forWorkspace id: WorkspaceID
    ) {
        workspaces[id, default: [:]][provider] = account
    }
}
