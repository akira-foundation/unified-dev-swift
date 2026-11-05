import Foundation

public struct AgentAccountResolution: Sendable {
    public let standings: [AgentAccountStanding]
    public let choices: [AgentKind: AgentAccountChoice]
    let stored: AgentAccountChoices

    public init(
        standings: [AgentAccountStanding],
        choices: [AgentKind: AgentAccountChoice],
        stored: AgentAccountChoices = .none
    ) {
        self.standings = standings
        self.choices = choices
        self.stored = stored
    }

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

    public func composerSection(repoID: RepoID?, provider: AgentKind) -> ComposerAccountSection? {
        ComposerAccountSection.make(
            repoID: repoID, provider: provider, choice: choice(for: provider), standings: standings
        )
    }

    public var options: AgentAccountOptions {
        AgentAccountOptions.make(choices: stored, standings: standings)
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
        let project = repoID ?? workspace?.repoID
        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(),
            defaults: defaults
        )
        let stored = try await store.agentAccountChoices()
            .choices(repoID: project)
        return AgentAccountResolution(
            standings: standings,
            choices: resolve(stored: stored, standings: standings),
            stored: stored
        )
    }

    public static func resolve(
        stored: AgentAccountChoices,
        standings: [AgentAccountStanding]
    ) -> [AgentKind: AgentAccountChoice] {
        Dictionary(uniqueKeysWithValues: AgentKind.allCases.map { provider in
            (provider, AgentAccountChoice.resolve(
                provider: provider,
                project: stored.project[provider],
                standings: standings
            ))
        })
    }
}
