import Foundation

public struct AgentModelSource: Sendable {
    public let models: @Sendable () async throws -> [AgentModel]
    public let invalidate: @Sendable () async -> Void

    public init(
        models: @escaping @Sendable () async throws -> [AgentModel],
        invalidate: @escaping @Sendable () async -> Void
    ) {
        self.models = models
        self.invalidate = invalidate
    }

    public static func kindsAwaitingModels(
        sources: [AgentKind: AgentModelSource],
        loaded: [AgentKind: [AgentModel]]
    ) -> [AgentKind] {
        AgentKind.runnable.filter { sources[$0] != nil && (loaded[$0] ?? []).isEmpty }
    }

    public static func live(
        store: Store? = nil,
        accounts: [AgentKind: AgentAccountHome] = [:]
    ) -> [AgentKind: AgentModelSource] {
        let claude = ClaudeModelSource.live(path: accounts[.claudeCode]?.identityPath.path)
        let codex = CodexModelCatalog.live(account: accounts[.codex])
        let grok = GrokModelCatalog.live(store: store, account: accounts[.grok])
        return [
            .claudeCode: AgentModelSource(
                models: { try await claude.models() },
                invalidate: { await claude.invalidate() }
            ),
            .codex: AgentModelSource(
                models: { try await codex.models().map(\.agentModel) },
                invalidate: { await codex.invalidate() }
            ),
            .grok: AgentModelSource(
                models: { try await grok.models().map(\.agentModel) },
                invalidate: { await grok.invalidate() }
            ),
        ]
    }
}
