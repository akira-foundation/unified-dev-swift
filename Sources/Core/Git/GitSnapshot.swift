import Foundation

public struct GitSnapshot: Codable, Sendable, Equatable {
    public let id: GitSnapshotID
    public let sessionID: SessionID
    public let createdAt: Date
    public let indexWasPresent: Bool?
    public var worktreeRef: String { "refs/unifieddev/checkpoints/\(id)/worktree" }
    public var indexRef: String { "refs/unifieddev/checkpoints/\(id)/index" }
    public var rawIndexRef: String { "refs/unifieddev/checkpoints/\(id)/raw-index" }

    public init(id: GitSnapshotID = .new(), sessionID: SessionID, createdAt: Date = Date(), indexWasPresent: Bool? = nil) {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.indexWasPresent = indexWasPresent
    }
}

public struct SnapshotFailure: Error, Sendable, CustomStringConvertible {
    public let description: String
    public init(_ message: String) { description = message }
}
