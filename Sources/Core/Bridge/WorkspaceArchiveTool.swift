import Foundation

public enum WorkspaceArchiveOutcome: Sendable, Equatable {
    case archived
    case requested
    case refused(String)
}

public struct WorkspaceArchiveOrder: Sendable, Hashable {
    public let workspace: Workspace
    public let afterTurnOf: SessionID?

    public init(workspace: Workspace, afterTurnOf: SessionID?) {
        self.workspace = workspace
        self.afterTurnOf = afterTurnOf
    }
}

public typealias WorkspaceArchiving = @Sendable (WorkspaceArchiveOrder) async -> WorkspaceArchiveOutcome

public struct WorkspaceArchiveTool: BridgeToolHandling {
    private let archive: WorkspaceArchiving

    public init(_ archive: @escaping WorkspaceArchiving) {
        self.archive = archive
    }

    public let roles: Set<BridgeRole> = [.owner, .parent]

    public let tool = BridgeTool(
        name: "workspace_archive",
        description: """
            Archive a workspace that is finished with. This removes the worktree and closes its \
            terminals and dev servers. Its branch, notes and chat history are kept, and the \
            workspace moves to Archived.

            If you are working in a workspace, this archives yours and there is nothing to pass: \
            do not name a workspace, it will be refused. You are still running, so the worktree \
            cannot go yet. The call is a request: Unified Dev checks again once your turn has ended and \
            archives then. Say everything you have to say in this same turn, because there will \
            not be another one, and do not report the workspace as archived. Only ask when the \
            work is done and the owner has said the workspace can go.

            From a client of the owner's own, pass 'id' with the exact workspace id from \
            workspace_list. Only call after the owner has asked for that workspace to be archived.

            The normal archive script runs if the project has one. Another agent running, queued \
            messages, uncommitted changes, local files that would be lost, or a failed safety \
            check refuses the call. There is no force option and no way to delete the branch. \
            Explain a refusal and let the owner resolve it or archive manually in Unified Dev. Do not \
            discard files just to make this tool succeed. An already archived workspace is a no-op.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The exact workspace id returned by workspace_list. Only from the owner's "
                            + "own client. An agent working in a workspace archives its own and "
                            + "must leave this out."
                    ),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ])
    )

    public func call(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async -> BridgeToolResult {
        let workspace: Workspace
        let asking: SessionID?
        switch await find(request, as: identity, store: store) {
        case .refused(let sentence): return .failure(sentence)
        case .found(let found, let session): (workspace, asking) = (found, session)
        }

        if workspace.state == .archived {
            return BridgeToolResult(text: "'\(workspace.name)' is already archived. Nothing changed.")
        }
        if let objection = await WorkspaceArchiveSafety.objection(
            to: workspace, excusing: asking, store: store
        ) {
            return .failure(objection)
        }

        switch await archive(WorkspaceArchiveOrder(workspace: workspace, afterTurnOf: asking)) {
        case .archived:
            return BridgeToolResult(text: "Archived '\(workspace.name)'. Its branch, notes and chat history were kept.")
        case .requested:
            return BridgeToolResult(text: """
                Archiving '\(workspace.name)' is requested, not done. Nothing has been removed and \
                you are still in the worktree. Unified Dev checks again when this turn ends, and \
                archives then if no agent is running here and nothing is queued; if it refuses, \
                the workspace stays and the owner is told why. This is your last turn in this \
                workspace, so finish what you were saying now, and do not report it as archived.
                """)
        case .refused(let reason):
            return .failure("The archive request was refused. \(reason)")
        }
    }

    private enum Subject {
        case found(Workspace, SessionID?)
        case refused(String)
    }

    private func find(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async -> Subject {
        guard roles.contains(identity.role) else {
            return .refused(
                "Only the owner's own client, or the agent working in a workspace, can archive one."
            )
        }

        var arguments: [String: JSONValue] = [:]
        if case .object(let object)? = request.params { arguments = object }

        guard identity.role == .owner else {
            guard arguments.isEmpty else {
                return .refused("""
                    workspace_archive archives the workspace you are in, which is the only one you \
                    may act in, so it takes no arguments. Ask again with none, and note that there \
                    is no force option and no way to delete the branch.
                    """)
            }
            guard let workspaceID = identity.workspaceID, let sessionID = identity.sessionID else {
                return .refused(BridgeWorkspaceScope.refusal(tool: "workspace_archive", doing: "archives"))
            }
            do {
                guard let own = try await store.workspace(id: workspaceID) else {
                    return .refused("That workspace is no longer in Unified Dev, so there is nothing to archive.")
                }
                return .found(own, sessionID)
            } catch {
                return .refused("Unified Dev could not read this workspace. Nothing was archived; try again shortly.")
            }
        }

        guard Set(arguments.keys) == ["id"],
              let rawID = request.stringParam("id")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawID.isEmpty else {
            return .refused("Pass only 'id', using the exact workspace id from workspace_list. There is no force option.")
        }
        do {
            guard let found = try await store.workspace(id: WorkspaceID(rawID)) else {
                return .refused("No workspace has that id. Call workspace_list and use the id it reports.")
            }
            return .found(found, nil)
        } catch {
            return .refused("Unified Dev could not read this workspace. Nothing was archived; try again shortly.")
        }
    }
}
