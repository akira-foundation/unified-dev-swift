import Foundation

public enum BridgeReadTarget: Sendable, Equatable {
    case own(WorkspaceID)
    case named(Workspace)

    public var workspaceID: WorkspaceID {
        switch self {
        case .own(let id): id
        case .named(let workspace): workspace.id
        }
    }

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
            return .success(.own(own))
        }
        switch try await BridgeWorkspaceLookup.activeTarget(given, store: store) {
        case .found(let workspace) where workspace.id == identity.workspaceID:
            return .success(.own(workspace.id))
        case .found(let workspace):
            return .success(.named(workspace))
        case .ambiguous(let ids):
            return .failure(.ambiguous(given: given, ids: ids))
        case .archived(let name):
            return .failure(.archived(name: name))
        case .unknown(let known):
            return .failure(.unknown(given: given, known: known))
        }
    }
}
