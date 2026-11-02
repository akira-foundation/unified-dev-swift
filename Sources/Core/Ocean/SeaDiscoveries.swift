import Foundation

public struct SeaDiscoveries: Equatable, Sendable {
    public static let symbol = "safari"

    private var notes: [WorkspaceID: String] = [:]

    public init() {}

    public mutating func record(_ pick: OceanPick?, for workspace: WorkspaceID) {
        guard let notice = pick?.notice else { return }
        notes[workspace] = notice
    }

    public mutating func leave(_ workspace: WorkspaceID?, for destination: WorkspaceID?) {
        guard let workspace, workspace != destination else { return }
        notes[workspace] = nil
    }

    public func label(for workspace: WorkspaceID) -> String? {
        notes[workspace]
    }
}
