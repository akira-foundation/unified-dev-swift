import Foundation

public struct SpendProviderCensus: Sendable, Hashable, Codable {
    public var keepsTranscripts: Bool
    public var files: Int
    public var pending: Int
    public var readAt: Date?

    public init(keepsTranscripts: Bool, files: Int, pending: Int, readAt: Date? = nil) {
        self.keepsTranscripts = keepsTranscripts
        self.files = files
        self.pending = pending
        self.readAt = readAt
    }
}

public struct SpendCensus: Sendable, Hashable, Codable {
    public var providers: [String: SpendProviderCensus]

    public init(providers: [String: SpendProviderCensus] = [:]) {
        self.providers = providers
    }

    public static let settingKey = "spend.census"

    public subscript(provider: AgentKind) -> SpendProviderCensus? {
        get { providers[provider.rawValue] }
        set { providers[provider.rawValue] = newValue }
    }
}
