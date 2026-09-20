import Foundation

public struct WhoamiTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.workspace, .owner]

    public let tool = BridgeTool(
        name: "whoami",
        description: """
            What this connection is: which copy of Unified Dev is at the other end of it, and which \
            workspace it is speaking for, if any. Inside a Unified Dev workspace that is the workspace \
            and its branch, the worktree path, the project it belongs to, and whether the \
            workspace was created by the owner or by another agent. From a client of the owner's \
            own it is the copy of Unified Dev you have reached and how much it is holding, which is the \
            cheapest way to confirm the connection works before asking it for anything real.

            Takes no arguments, because Unified Dev already knows who is calling. Read only.
            """,
        inputSchema: BridgeTool.noArguments
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else { return await owner(store: store) }
        do {
            guard let workspace = try await store.workspace(id: workspaceID) else {
                return .failure("This workspace is no longer in Unified Dev's database.")
            }
            var session: Session?
            if let sessionID = identity.sessionID {
                session = try await store.session(id: sessionID)
            }
            let repo = try await store.repo(id: workspace.repoID)

            var answer: [String: JSONValue] = [
                "role": .string(identity.role.rawValue),
                "workspace": .object([
                    "id": .string(workspace.id.rawValue),
                    "name": .string(workspace.name),
                    "branch": .string(workspace.branch),
                    "base_branch": .string(workspace.baseBranch),
                    "path": .string(workspace.path),
                    "state": .string(workspace.state.rawValue),
                ]),
                "session": .object([
                    "id": .string(identity.sessionID?.rawValue ?? ""),
                    "title": .string(session?.title ?? ""),
                    "agent": .string((session?.agentKind ?? .claudeCode).rawValue),
                ]),
            ]
            if let repo {
                answer["project"] = .object([
                    "id": .string(repo.id.rawValue),
                    "name": .string(repo.name),
                    "path": .string(repo.path),
                    "default_branch": .string(repo.defaultBranch),
                ])
            }
            switch workspace.origin {
            case .user:
                answer["created_by"] = .string("owner")
            case .agent(let parentWorkspaceID, let spawnToolUseID):
                answer["created_by"] = .object([
                    "agent_in_workspace": .string(parentWorkspaceID.rawValue),
                    "spawn_tool_use_id": .string(spawnToolUseID),
                ])
            case .ownerClient:
                answer["created_by"] = .string("owner")
            }
            return .json(.object(answer))
        } catch {
            return .failure("Unified Dev could not read this workspace: \(error.readableMessage)")
        }
    }

    private func owner(store: Store) async -> BridgeToolResult {
        do {
            let projects = try await store.repos()
            let workspaces = try await store.workspaces()
            return .json(.object([
                "role": .string(BridgeRole.owner.rawValue),
                "connected_to": .object([
                    "app": .string("Unified Dev"),
                    "database": .string(store.path),
                    "bridge_protocol": .integer(BridgeProtocol.version),
                ]),
                "projects": .integer(projects.count),
                "workspaces": .integer(workspaces.count),
                "note": .string(
                    "You are talking to Unified Dev as its owner, from outside any workspace. You can "
                        + "list projects, register an existing repository as one, and start "
                        + "workspaces in them."
                ),
            ]))
        } catch {
            return .failure("Unified Dev could not read its own database: \(error.readableMessage)")
        }
    }
}
