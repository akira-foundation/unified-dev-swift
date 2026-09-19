import Foundation

extension WorkspaceStartTool {
    enum Resolution {
        case resolved(Repo, Caller?)
        case refused(String)
    }

    struct Caller {
        let workspaceID: WorkspaceID
        let repoID: RepoID
    }

    func resolve(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> Resolution {
        let named = filled(request.param("project"))

        do {
            guard let workspaceID = identity.workspaceID else {
                guard let named else {
                    return .refused(
                        "workspace_start needs a project, because this connection is not running "
                            + "inside a Unified Dev workspace and nothing else says where the work "
                            + "should go. Call project_list to see what Unified Dev has."
                    )
                }
                return try await lookUp(named, store: store, asking: nil)
            }

            guard let caller = try await store.workspace(id: workspaceID) else {
                return .refused("This workspace is no longer in Unified Dev's database.")
            }
            guard let project = try await store.repo(id: caller.repoID) else {
                return .refused("This workspace's project is no longer in Unified Dev's database.")
            }

            if caller.origin.isAgentSpawned {
                return .refused(
                    "This workspace was itself started by an agent, and those cannot start more. "
                        + "Do the work here, or report back and let the owner decide."
                )
            }

            let asking = Caller(workspaceID: workspaceID, repoID: caller.repoID)
            guard let named else { return .resolved(project, asking) }
            return try await lookUp(named, store: store, asking: asking)
        } catch {
            return .refused("Unified Dev could not read its projects: \(error.readableMessage)")
        }
    }

    private func lookUp(_ named: String, store: Store, asking: Caller?) async throws -> Resolution {
        let projects = try await store.repos()
        let outcome = BridgeProjectLookup.find(named, in: projects)
        if let refusal = BridgeProjectLookup.refusal(for: named, outcome: outcome, projects: projects) {
            return .refused(refusal)
        }
        guard case .found(let project) = outcome else {
            return .refused("Unified Dev has no project called '\(named)'.")
        }
        return .resolved(project, asking)
    }

    func origin(of order: AgentWorkspaceOrder, project: Repo, parent: Caller?) -> WorkspaceOrigin {
        guard let parent else {
            return .ownerClient(spawnToolUseID: order.spawnID(ownerProject: project.id))
        }
        return .agent(
            parentWorkspaceID: parent.workspaceID,
            spawnToolUseID: order.spawnID(
                parentWorkspaceID: parent.workspaceID,
                otherProject: project.id == parent.repoID ? nil : project.id
            )
        )
    }
}
