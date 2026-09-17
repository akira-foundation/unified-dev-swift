import Foundation

public struct ProjectListTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.owner]

    public let tool = BridgeTool(
        name: "project_list",
        description: """
            The projects Unified Dev knows about: the name and the path of each git repository \
            registered in the sidebar, its default branch, how many workspaces it has, how many \
            of those have an agent working or stopped on a question, whether it is still where \
            Unified Dev recorded it, and whether the owner has hidden it from the sidebar.

            Those are three different numbers and none of them stands in for another. \
            workspaces counts the worktrees the project has that nobody has archived, whether or \
            not anything is happening in them, and it is what the sidebar draws under the \
            project. agents_running counts how many of those have an agent mid turn right now, \
            and awaiting_permission how many have one stopped on a permission question. A \
            project with workspaces and agents_running 0 has worktrees sitting idle, which is not \
            the same as having none, and a project with workspaces 0 has none at all.

            workspace_list names those same workspaces one by one and is counted from the same \
            rows, so this project's workspaces is how many it lists for the project and its \
            agents_running is how many of them it marks agent_running.

            Call it before naming a project in any other tool, because Unified Dev will only act on \
            repositories it already has and this is the list of them. Every project here can be \
            worked in, hidden or not: hidden is a view preference of the owner's sidebar and \
            says nothing about whether the project is finished with. Takes no arguments, reads \
            nothing but Unified Dev's own database, changes nothing and costs nothing.
            """,
        inputSchema: BridgeTool.noArguments
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        do {
            let projects = try await store.repos()
            guard !projects.isEmpty else {
                return .json(.object([
                    "projects": .array([]),
                    "note": .string(
                        "Unified Dev has no projects yet. Register an existing git repository with "
                            + "project_add."
                    ),
                ]))
            }

            let census = try await BridgeWorkspaceCensus.read(from: store)

            var rows: [JSONValue] = []
            for project in projects {
                let counts = census.counts(repoID: project.id)
                rows.append(.object([
                    "id": .string(project.id.rawValue),
                    "name": .string(project.name),
                    "path": .string(project.path),
                    "default_branch": .string(project.defaultBranch),
                    "workspaces": .integer(counts.workspaces),
                    "agents_running": .integer(counts.agentsRunning),
                    "awaiting_permission": .integer(counts.awaitingPermission),
                    "on_disk": .bool(FileManager.default.fileExists(atPath: project.path)),
                    "hidden": .bool(project.hidden),
                ]))
            }

            let hidden = ProjectVisibility.hiddenCount(projects)
            guard hidden > 0 else { return .json(.object(["projects": .array(rows)])) }
            return .json(.object([
                "projects": .array(rows),
                "hidden_projects": .integer(hidden),
                "note": .string(
                    "\(hidden == 1 ? "One project is" : "\(hidden) projects are") hidden from "
                        + "Unified Dev's sidebar. That is a view preference and nothing else: they are "
                        + "still projects, their workspaces still run, and project_unhide puts "
                        + "one back in the list."
                ),
            ]))
        } catch {
            return .failure("Unified Dev could not read its projects: \(error.readableMessage)")
        }
    }
}
