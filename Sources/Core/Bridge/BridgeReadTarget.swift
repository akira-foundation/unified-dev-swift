import Foundation

public enum BridgeReadTarget: Sendable, Equatable {
    case own(Workspace)
    case named(Workspace)

    public var workspace: Workspace {
        switch self {
        case .own(let workspace), .named(let workspace): workspace
        }
    }

    public var workspaceID: WorkspaceID { workspace.id }

    static let argument = "workspace"

    static let schemaProperty: JSONValue = .object([
        "type": .string("string"),
        "description": .string(
            "Another workspace to read, by the id workspace_list or workspace_start reports, or by "
                + "its name when no other active workspace shares it. Leave it out to read your own. "
                + "Required from a client that is not working in a workspace."
        ),
    ])

    static func resolve(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async throws -> Result<BridgeReadTarget, BridgeReadTrouble> {
        var given: String?
        if let raw = request.param(argument), raw != .null {
            guard let text = raw.stringValue else { return .failure(.notText) }
            given = AgentStartTool.text(text)
        }
        guard let given else {
            guard let own = identity.workspaceID else { return .failure(.noWorkspaceNamed) }
            return try await ownWorkspace(own, store: store)
        }
        switch try await BridgeWorkspaceLookup.activeTarget(given, store: store) {
        case .found(let workspace) where workspace.id == identity.workspaceID:
            return .success(.own(workspace))
        case .found(let workspace):
            return .success(.named(workspace))
        case .ambiguous(let ids):
            return .failure(.ambiguous(given: given, ids: ids))
        case .archived:
            return .failure(.archived(given: given))
        case .unknown(let known):
            return .failure(.unknown(given: given, known: known))
        }
    }

    private static func ownWorkspace(
        _ id: WorkspaceID, store: Store
    ) async throws -> Result<BridgeReadTarget, BridgeReadTrouble> {
        guard let workspace = try await store.workspace(id: id) else { return .failure(.callerHasGone) }
        guard workspace.state != .archived else { return .failure(.callerArchived) }
        return .success(.own(workspace))
    }
}
