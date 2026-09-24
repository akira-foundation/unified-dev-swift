import Foundation

public struct ClaudeModelMemory: Sendable, Hashable {
    public static let settingKey = "models.claude.named"

    public private(set) var ids: [String]

    public init(ids: [String] = []) {
        self.ids = Self.tidied(ids)
    }

    public static func decode(_ raw: String?) -> ClaudeModelMemory {
        ClaudeModelMemory(ids: (raw ?? "").split(whereSeparator: \.isNewline).map(String.init))
    }

    public var encoded: String? {
        ids.isEmpty ? nil : ids.joined(separator: "\n")
    }

    @discardableResult
    public mutating func remember(_ id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isNew(trimmed, among: ids) else { return false }
        ids.append(trimmed)
        return true
    }

    @discardableResult
    public mutating func forget(_ id: String) -> Bool {
        let before = ids.count
        ids.removeAll { $0 == id }
        return ids.count != before
    }

    public func models(including current: String = "") -> [AgentModel] {
        ClaudeModelCatalog.offered(named: ids, including: current)
    }

    public static func load(from store: Store) async -> ClaudeModelMemory {
        decode(try? await store.setting(settingKey))
    }

    public func save(to store: Store) async throws {
        try await store.setSetting(Self.settingKey, encoded)
    }

    static func isNew(_ id: String, among kept: [String]) -> Bool {
        !id.isEmpty && !ClaudeModelCatalog.isBuiltIn(id) && !kept.contains(id)
    }

    static func tidied(_ ids: [String]) -> [String] {
        var kept: [String] = []
        for id in ids {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isNew(trimmed, among: kept) else { continue }
            kept.append(trimmed)
        }
        return kept
    }
}
