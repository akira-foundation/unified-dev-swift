import Foundation

public enum ClaudeModelCatalog {
    public static let builtIn: [AgentModel] = [
        AgentModel(id: "fable", displayName: "Fable"),
        AgentModel(id: "opus", displayName: "Opus"),
        AgentModel(id: "sonnet", displayName: "Sonnet"),
        AgentModel(id: "haiku", displayName: "Haiku"),
    ]

    public static func isBuiltIn(_ id: String) -> Bool {
        builtIn.contains { $0.id == id }
    }

    public static func offered(
        read: [AgentModel] = [],
        including current: String = "",
        reported: [String: String] = [:]
    ) -> [AgentModel] {
        var seen = Set<String>()
        var models: [AgentModel] = []

        let aliases = builtIn.map { versioned($0, listed: read, reported: reported) }
        for model in aliases + read + [AgentModel(id: current, displayName: current)] {
            let id = model.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            models.append(renamed(model, id: id))
        }

        let byID = Dictionary(models.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ClaudeModelRank.ordered(models.map(\.id)).compactMap { byID[$0] }
    }

    private static func versioned(
        _ alias: AgentModel,
        listed: [AgentModel],
        reported: [String: String]
    ) -> AgentModel {
        guard let version = ClaudeResolvedModel.version(ofAlias: alias.id, listed: listed, reported: reported) else {
            return alias
        }
        return AgentModel(id: alias.id, displayName: "\(alias.displayName) \(version)")
    }

    static func renamed(_ model: AgentModel, id: String) -> AgentModel {
        guard model.displayName == id, !isBuiltIn(id) else { return model }
        return AgentModel(id: id, displayName: ModelLabel.readable(id))
    }
}

public actor ClaudeModelSource {
    public static let freshness = AgentModelCache<AgentModel>.freshness

    private let cache: AgentModelCache<AgentModel>

    public init(read: @escaping @Sendable () async -> Data?) {
        cache = AgentModelCache(fetch: {
            ClaudeModelCatalog.offered(read: ClaudeModelOptions.decode(await read()))
        })
    }

    public static func live(path: String? = nil) -> ClaudeModelSource {
        let file = path ?? AgentCatalog.claudeAccountPath
        return ClaudeModelSource(read: { FileManager.default.contents(atPath: file) })
    }

    public func models() async throws -> [AgentModel] {
        try await cache.models()
    }

    public func invalidate() async {
        await cache.invalidate()
    }
}
