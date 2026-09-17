import Foundation

public enum WorkspaceOrigin: Sendable, Equatable, Hashable, Codable {
    case user

    case agent(parentWorkspaceID: WorkspaceID, spawnToolUseID: String)

    case ownerClient(spawnToolUseID: String)

    public var parentWorkspaceID: WorkspaceID? {
        switch self {
        case .user, .ownerClient: nil
        case .agent(let parent, _): parent
        }
    }

    public var spawnToolUseID: String? {
        switch self {
        case .user: nil
        case .agent(_, let toolUse): toolUse
        case .ownerClient(let toolUse): toolUse
        }
    }

    public var isAgentSpawned: Bool { parentWorkspaceID != nil }

    public var isOwnerClient: Bool {
        if case .ownerClient = self { return true }
        return false
    }

    public init(parentWorkspaceID: String?, spawnToolUseID: String?) {
        let parent = (parentWorkspaceID?.isEmpty ?? true) ? nil : parentWorkspaceID
        let spawn = (spawnToolUseID?.isEmpty ?? true) ? nil : spawnToolUseID

        switch (parent, spawn) {
        case let (parent?, spawn?):
            self = .agent(parentWorkspaceID: WorkspaceID(parent), spawnToolUseID: spawn)
        case let (nil, spawn?):
            self = .ownerClient(spawnToolUseID: spawn)
        case (_, nil):
            self = .user
        }
    }
}
