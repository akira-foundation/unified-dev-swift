import Foundation

public struct SpendRecord: Sendable, Hashable {
    public enum KeyScope: Sendable, Hashable {
        case response
        case transcript
    }

    public var provider: AgentKind
    public var happenedAt: Date
    public var model: String
    public var directory: String
    public var key: String
    public var keyScope: KeyScope
    public var usage: TokenUsage

    public init(
        provider: AgentKind,
        happenedAt: Date,
        model: String,
        directory: String,
        key: String = "",
        keyScope: KeyScope = .transcript,
        usage: TokenUsage
    ) {
        self.provider = provider
        self.happenedAt = happenedAt
        self.model = model
        self.directory = directory
        self.key = key
        self.keyScope = keyScope
        self.usage = usage
    }

    public static func offsetKey(_ offset: Int) -> String { "o\(offset)" }

    public func storedKey(inFile file: String) -> String {
        switch keyScope {
        case .response: key
        case .transcript: file + "#" + key
        }
    }
}

public struct TranscriptCarry: Sendable, Hashable {
    public var model: String
    public var directory: String
    public var isDiscarding: Bool

    public init(model: String = "", directory: String = "", isDiscarding: Bool = false) {
        self.model = model
        self.directory = directory
        self.isDiscarding = isDiscarding
    }
}
