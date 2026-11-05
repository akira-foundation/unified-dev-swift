import Foundation

public struct ProfileMemory: Codable, Equatable, Sendable {
    public var lastWorkspace: [ProfileID: WorkspaceID]

    public init(lastWorkspace: [ProfileID: WorkspaceID] = [:]) {
        self.lastWorkspace = lastWorkspace
    }

    public mutating func remember(_ workspace: WorkspaceID, in profile: ProfileID) {
        lastWorkspace[profile] = workspace
    }

    public func landing(for profile: ProfileID, live: Set<WorkspaceID>) -> SidebarSelection {
        guard let id = lastWorkspace[profile], live.contains(id) else { return .home }
        return .workspace(id)
    }
}
