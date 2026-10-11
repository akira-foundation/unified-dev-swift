import Foundation

public struct SpendRecord: Sendable, Hashable {
    public var provider: AgentKind
    public var happenedAt: Date
    public var model: String
    public var directory: String
    public var usage: TokenUsage

    public init(
        provider: AgentKind,
        happenedAt: Date,
        model: String,
        directory: String,
        usage: TokenUsage
    ) {
        self.provider = provider
        self.happenedAt = happenedAt
        self.model = model
        self.directory = directory
        self.usage = usage
    }
}

public struct TranscriptCarry: Sendable, Hashable {
    public var model: String
    public var directory: String

    public init(model: String = "", directory: String = "") {
        self.model = model
        self.directory = directory
    }
}
