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

    public static func live(store: Store? = nil) -> [AgentKind: AgentModelSource] {
        let claude = ClaudeModelSource.live()
        let codex = CodexModelCatalog.live()
        let grok = GrokModelCatalog.live(store: store)
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
