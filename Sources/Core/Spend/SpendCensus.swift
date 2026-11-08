import Foundation

public struct SpendProviderCensus: Sendable, Hashable, Codable {
    public var keepsTranscripts: Bool
    public var files: Int
    public var pending: Int

    public init(keepsTranscripts: Bool, files: Int, pending: Int) {
        self.keepsTranscripts = keepsTranscripts
        self.files = files
        self.pending = pending
    }
}

public struct SpendCensus: Sendable, Hashable, Codable {
    public var providers: [String: SpendProviderCensus]

    public init(providers: [String: SpendProviderCensus] = [:]) {
        self.providers = providers
    }

    public static let settingKey = "spend.census"

    public mutating func add(_ provider: AgentKind, files: Int, pending: Int) {
        var seen = self[provider] ?? SpendProviderCensus(keepsTranscripts: true, files: 0, pending: 0)
        seen.files += files
        seen.pending += pending
        self[provider] = seen
    }

    public subscript(provider: AgentKind) -> SpendProviderCensus? {
        get { providers[provider.rawValue] }
        set { providers[provider.rawValue] = newValue }
    }
}
