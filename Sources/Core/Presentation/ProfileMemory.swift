import Foundation

public struct ProfileMemory: Codable, Equatable, Sendable {
    public var lastWorkspace: [ProfileID: WorkspaceID]

    public init(lastWorkspace: [ProfileID: WorkspaceID] = [:]) {
        self.lastWorkspace = lastWorkspace
    }

    public mutating func remember(_ workspace: WorkspaceID, in profile: ProfileID) {
        lastWorkspace[profile] = workspace
    }

    public mutating func forget(_ profile: ProfileID) {
        lastWorkspace[profile] = nil
    }

    public static func restored(stored: Data?, legacyLastWorkspace: String?) -> ProfileMemory {
        if let stored, let memory = try? JSONDecoder().decode(ProfileMemory.self, from: stored) {
            return memory
        }
        guard let legacyLastWorkspace, !legacyLastWorkspace.isEmpty else { return ProfileMemory() }
        return ProfileMemory(lastWorkspace: [.initial: WorkspaceID(legacyLastWorkspace)])
    }

    public func landing(for profile: ProfileID, live: Set<WorkspaceID>) -> SidebarSelection {
        guard let id = lastWorkspace[profile], live.contains(id) else { return .home }
        return .workspace(id)
    }
}
