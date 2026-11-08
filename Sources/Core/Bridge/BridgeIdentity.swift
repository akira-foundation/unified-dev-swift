import Foundation

public enum BridgeRole: String, Sendable, Hashable, Codable, CaseIterable {
    case workspace
    case owner
}

public struct BridgeIdentity: Sendable, Hashable {
    public let sessionID: SessionID?
    public let workspaceID: WorkspaceID?
    public let role: BridgeRole
    public let pinnedProfile: ProfileID?

    public init(sessionID: SessionID, workspaceID: WorkspaceID, role: BridgeRole) {
        self.sessionID = sessionID
        self.workspaceID = workspaceID
        self.role = role
        self.pinnedProfile = nil
    }

    private init(role: BridgeRole) {
        self.sessionID = nil
        self.workspaceID = nil
        self.role = role
        self.pinnedProfile = nil
    }

    public init(ownerSession sessionID: SessionID, pinnedProfile: ProfileID? = nil) {
        self.sessionID = sessionID
        self.workspaceID = nil
        self.role = .owner
        self.pinnedProfile = pinnedProfile
    }

    public static let owner = BridgeIdentity(role: .owner)
}
