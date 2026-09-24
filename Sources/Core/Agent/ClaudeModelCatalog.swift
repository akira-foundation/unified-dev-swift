import Foundation

public enum ClaudeModelCatalog {
    public static let builtIn: [AgentModel] = [
        AgentModel(id: "fable", displayName: "Fable 5.1"),
        AgentModel(id: "opus", displayName: "Opus 5"),
        AgentModel(id: "sonnet", displayName: "Sonnet 5"),
        AgentModel(id: "haiku", displayName: "Haiku 4.5"),
    ]

    public static func isBuiltIn(_ id: String) -> Bool {
        builtIn.contains { $0.id == id }
    }

    public static func offered(named: [String] = [], including current: String = "") -> [AgentModel] {
        var seen = Set(builtIn.map(\.id))
        var models = builtIn

        for id in named + [current] {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            models.append(AgentModel(id: trimmed, displayName: ModelLabel.readable(trimmed)))
        }

        let byID = Dictionary(models.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ClaudeModelRank.ordered(models.map(\.id)).compactMap { byID[$0] }
    }
}
