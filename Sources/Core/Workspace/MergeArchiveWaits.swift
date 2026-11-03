import Foundation

public struct MergeArchiveWaits: Sendable, Equatable {
    public enum Settlement: Sendable, Equatable {
        case notWaiting
        case keepWaiting
        case archive(pullRequest: Int)
        case dropStopped
    }

    public static let recheckInterval = Duration.seconds(5)

    public private(set) var pullRequests: [WorkspaceID: Int] = [:]

    public init() {}

    public var ids: Set<WorkspaceID> { Set(pullRequests.keys) }

    public mutating func wait(for id: WorkspaceID, pullRequest: Int) {
        pullRequests[id] = pullRequest
    }

    public mutating func forget(_ id: WorkspaceID) {
        pullRequests[id] = nil
    }

    public mutating func record(_ decision: MergeArchiveDecision, for id: WorkspaceID, pullRequest: Int) {
        switch decision {
        case .archiveAfterTurn, .waitForCommand:
            wait(for: id, pullRequest: pullRequest)
        case .archiveNow, .forget:
            forget(id)
        case .leave:
            break
        }
    }

    public mutating func settle(
        _ id: WorkspaceID, isAgentMidTurn: Bool, isCommandRunning: Bool, wasStopped: Bool
    ) -> Settlement {
        guard let pullRequest = pullRequests[id] else { return .notWaiting }
        if wasStopped {
            pullRequests[id] = nil
            return .dropStopped
        }
        guard !isAgentMidTurn, !isCommandRunning else { return .keepWaiting }
        pullRequests[id] = nil
        return .archive(pullRequest: pullRequest)
    }
}
