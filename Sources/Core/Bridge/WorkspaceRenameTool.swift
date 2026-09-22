import Foundation

public enum WorkspaceRenameTrouble: Error, Sendable, Equatable {
    case noName
    case namedAnother(String)
    case namedItself
    case noWorkspaceNamed
    case unknown(given: String, known: [String])
    case ambiguous(given: String, ids: [String])
    case notInAWorkspace
    case gone
    case unexplained(String)

    public var sentence: String {
        switch self {
        case .noName:
            return """
                workspace_rename needs the 'name' to give the workspace, and it cannot be blank. \
                A workspace with no name is a row in the sidebar nobody can pick out, and there is \
                no field on this side of the socket to type one back into. Pass the name you want \
                it to have.
                """

        case .namedAnother(let given):
            return """
                workspace_rename renames the workspace you are in, or one you started with \
                workspace_start, and '\(given)' is neither. Leave 'workspace' out to rename your \
                own, or pass the id workspace_start reported. Retrying with the same value will \
                fail the same way.
                """

        case .namedItself:
            return """
                That is the workspace you are in. Leave 'workspace' out to rename your own, which \
                is what this call does with no argument.
                """

        case .noWorkspaceNamed:
            return """
                workspace_rename needs to be told which workspace to rename, because this \
                connection is not sitting in one. Pass 'workspace' with the name or the id \
                workspace_list prints.
                """

        case let .unknown(given, known):
            guard !known.isEmpty else {
                return """
                    Unified Dev has no workspaces at all, so there is nothing called '\(given)' to \
                    rename. Retrying will not change that.
                    """
            }
            return """
                Unified Dev has no workspace called '\(given)'. It has \
                \(BridgeWorkspaceLookup.list(known)). Retrying with the same name will fail the \
                same way: call workspace_list and pass a name or an id from its answer.
                """

        case let .ambiguous(given, ids):
            return """
                \(ids.count) workspaces are called '\(given)', so renaming one of them would be \
                renaming a workspace you did not name. Pass the id instead, which workspace_list \
                prints: \(BridgeWorkspaceLookup.list(ids)).
                """

        case .notInAWorkspace:
            return BridgeWorkspaceScope.refusal(tool: "workspace_rename", doing: "renames")

        case .gone:
            return """
                That workspace is no longer in Unified Dev, so nothing was renamed. Its row has gone, \
                which retrying will not undo.
                """

        case .unexplained(let message):
            return "Unified Dev could not rename that workspace: \(message)"
        }
    }
}

public struct WorkspaceRenameTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.workspace, .owner]

    public let tool = BridgeTool(
        name: "workspace_rename",
        description: """
            Rename a workspace. Use it when what the workspace turned out to be about is not what \
            it is called, which is most workspaces called 'test', 'fix' or after a branch that has \
            since grown. The name is what the sidebar, Home and every other tool here calls it, so \
            a wrong one is wrong everywhere.

            'name' is what to call it and is required. It cannot be blank.

            If you are working in a workspace, leave 'workspace' out to rename yours, or pass the \
            name or id of a workspace you started with workspace_start. Any other workspace is \
            refused. From a client of the owner's own, pass 'workspace' with the name or the id \
            workspace_list prints. A name two workspaces share is refused rather than guessed at.

            It renames and nothing else. The branch, the worktree and the pull request keep the \
            names they have, and nothing on disk moves. It is not destructive: the answer carries \
            the name the workspace had, so calling again with that puts it back, and the owner can \
            double click the row in the sidebar and type over it.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What to call the workspace: a few words on one line, up to \(WorkspaceName.limit) "
                            + "characters. Unified Dev keeps it to that and drops control and format characters."
                    ),
                ]),
                "workspace": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Which workspace to rename, by name or id. From an agent working in a "
                            + "workspace, only one it started with workspace_start; leave it out to "
                            + "rename your own. From the owner's own client, any workspace."
                    ),
                ]),
            ]),
            "required": .array([.string("name")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let name = WorkspaceName.given(request.stringParam("name")) else {
            return .failure(WorkspaceRenameTrouble.noName.sentence)
        }

        let workspace: Workspace
        switch await find(named: WorkspaceName.given(request.stringParam("workspace")),
                          as: identity, store: store) {
        case .failure(let trouble): return .failure(trouble.sentence)
        case .success(let found): workspace = found
        }

        guard workspace.name != name else {
            return .json(answer(workspace: workspace, was: workspace.name, changed: false))
        }

        do {
            guard let renamed = try await store.update(workspaceID: workspace.id, { $0.name = name })
            else {
                return .failure(WorkspaceRenameTrouble.gone.sentence)
            }
            return .json(answer(workspace: renamed, was: workspace.name, changed: true))
        } catch {
            return .failure(WorkspaceRenameTrouble.unexplained(error.readableMessage).sentence)
        }
    }

    private func find(
        named: String?,
        as identity: BridgeIdentity,
        store: Store
    ) async -> Result<Workspace, WorkspaceRenameTrouble> {
        guard identity.role == .owner else {
            guard let workspaceID = identity.workspaceID else { return .failure(.notInAWorkspace) }
            do {
                guard let named else {
                    guard let own = try await store.workspace(id: workspaceID) else {
                        return .failure(.gone)
                    }
                    return .success(own)
                }
                if named.caseInsensitiveCompare(workspaceID.rawValue) == .orderedSame {
                    return .failure(.namedItself)
                }
                let started = try await store.workspaces(startedBy: workspaceID, includeArchived: true)
                switch BridgeWorkspaceLookup.find(named, among: started) {
                case .found(let workspace):
                    return .success(workspace)
                case .unknown:
                    return .failure(.namedAnother(named))
                case .ambiguous(let matches):
                    return .failure(.ambiguous(given: named, ids: matches.map(\.id.rawValue)))
                }
            } catch {
                return .failure(.unexplained(error.readableMessage))
            }
        }

        guard let named else { return .failure(.noWorkspaceNamed) }
        let workspaces: [Workspace]
        do {
            workspaces = try await store.workspaces(includeArchived: true)
        } catch {
            return .failure(.unexplained(error.readableMessage))
        }

        switch BridgeWorkspaceLookup.find(named, among: workspaces) {
        case .found(let workspace):
            return .success(workspace)
        case .unknown:
            return .failure(.unknown(given: named, known: workspaces.map(\.name)))
        case .ambiguous(let matches):
            return .failure(.ambiguous(given: named, ids: matches.map(\.id.rawValue)))
        }
    }

    private func answer(workspace: Workspace, was: String, changed: Bool) -> JSONValue {
        .object([
            "workspace_id": .string(workspace.id.rawValue),
            "name": .string(workspace.name),
            "previous_name": .string(was),
            "branch": .string(workspace.branch),
            "renamed": .bool(changed),
            "note": .string(changed
                ? "The sidebar is showing '\(workspace.name)'. Nothing else moved: the branch is "
                    + "still '\(workspace.branch)' and so is the worktree. To put the old name "
                    + "back, call workspace_rename again with '\(was)'."
                : "It was already called '\(workspace.name)', so nothing was written."),
        ])
    }
}
