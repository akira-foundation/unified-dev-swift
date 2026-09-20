import Foundation

public enum BridgeRole: String, Sendable, Hashable, Codable, CaseIterable {
    case parent
    case child
    case owner

    public init(origin: WorkspaceOrigin) {
        self = origin.isAgentSpawned ? .child : .parent
    }
}

public struct BridgeIdentity: Sendable, Hashable {
    public let sessionID: SessionID?
    public let workspaceID: WorkspaceID?
    public let role: BridgeRole

    public init(sessionID: SessionID, workspaceID: WorkspaceID, role: BridgeRole) {
        self.sessionID = sessionID
        self.workspaceID = workspaceID
        self.role = role
    }

    private init(role: BridgeRole) {
        self.sessionID = nil
        self.workspaceID = nil
        self.role = role
    }

    public init(ownerSession sessionID: SessionID) {
        self.sessionID = sessionID
        self.workspaceID = nil
        self.role = .owner
    }

    public static let owner = BridgeIdentity(role: .owner)
}
