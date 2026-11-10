import Foundation

public struct ClaudeAliasAnswers: Sendable, Equatable {
    public var probed: [String: String] = [:]
    public var pinned: [String: String] = [:]

    public init(probed: [String: String] = [:], pinned: [String: String] = [:]) {
        self.probed = probed
        self.pinned = pinned
    }

    public var all: [String: String] {
        probed.merging(pinned) { _, pin in pin }
    }
}
