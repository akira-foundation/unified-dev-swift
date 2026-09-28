import Foundation

public struct WorkspaceStartHold: Equatable, Sendable {
    public private(set) var ids: Set<WorkspaceID> = []

    public static let cliLaunchGrace: Duration = .seconds(10)

    public init() {}

    public func contains(_ id: WorkspaceID) -> Bool {
        ids.contains(id)
    }

    public mutating func begin(_ id: WorkspaceID) {
        ids.insert(id)
    }

    public mutating func release(_ id: WorkspaceID) {
        ids.remove(id)
    }

    public mutating func settle(running: Set<WorkspaceID>) {
        ids.subtract(running)
    }

    public static func releaseDelay(afterCLILaunch: Bool) -> Duration? {
        afterCLILaunch ? cliLaunchGrace : nil
    }
}
