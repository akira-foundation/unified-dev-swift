import Foundation

public struct AgentAccountResolution: Sendable {
    public let standings: [AgentAccountStanding]
    public let choices: [AgentKind: AgentAccountChoice]

    public func choice(for provider: AgentKind) -> AgentAccountChoice {
        choices[provider] ?? AgentAccountChoice(home: nil, reason: .noAccount)
    }

    public func home(for provider: AgentKind) -> AgentAccountHome? {
        choice(for: provider).home
    }

    public func isPresent(_ account: AgentAccountID) -> Bool {
        AgentAccountChoice.present(in: standings).contains { $0.id == account }
    }

    public var homes: [AgentKind: AgentAccountHome] {
        choices.compactMapValues(\.home)
    }

    public func line(for provider: AgentKind) -> AgentAccountLine {
        AgentAccountLine.make(choice: choice(for: provider), provider: provider, standings: standings)
    }
}

public enum AgentAccountResolver {
    public static func resolve(
        workspaceID: WorkspaceID?,
        repoID: RepoID?,
        store: Store,
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes()
    ) async throws -> AgentAccountResolution {
        var workspace: Workspace?
        if let workspaceID { workspace = try await store.workspace(id: workspaceID) }
        var repo: Repo?
        if let id = repoID ?? workspace?.repoID { repo = try await store.repo(id: id) }
        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(),
            defaults: defaults
        )
        let choices = Dictionary(uniqueKeysWithValues: AgentKind.allCases.map { provider in
            (provider, AgentAccountChoice.resolve(
                provider: provider,
                workspace: workspace?.accountID,
                project: repo?.accountID,
                standings: standings
            ))
        })
        return AgentAccountResolution(standings: standings, choices: choices)
    }
}
