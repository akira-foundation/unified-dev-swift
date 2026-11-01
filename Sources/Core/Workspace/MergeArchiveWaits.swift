import Foundation

public struct MergeArchiveWaits: Sendable, Equatable {
    public enum Settlement: Sendable, Equatable {
        case notWaiting
        case keepWaiting
        case archive
        case dropStopped
    }

    public private(set) var ids: Set<WorkspaceID> = []

    public init() {}

    public mutating func wait(for id: WorkspaceID) {
        ids.insert(id)
    }

    public mutating func forget(_ id: WorkspaceID) {
        ids.remove(id)
    }

    public mutating func settle(_ id: WorkspaceID, isAgentMidTurn: Bool, wasStopped: Bool) -> Settlement {
        guard ids.contains(id) else { return .notWaiting }
        if wasStopped {
            ids.remove(id)
            return .dropStopped
        }
        guard !isAgentMidTurn else { return .keepWaiting }
        ids.remove(id)
        return .archive
    }
}
