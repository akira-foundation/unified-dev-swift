import Foundation

public struct ProjectHideTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.owner]

    public let tool = BridgeTool(
        name: "project_hide",
        description: """
            Hide a project from Unified Dev's sidebar, so its row and its workspaces are left out of \
            the project list. Takes the project's name, its absolute path, or the id \
            project_list prints.

            This is a view preference and nothing more. It stops nothing, closes nothing and \
            deletes nothing: the project's agents keep running, its worktrees stay exactly where \
            they are, and its workspaces still appear on Unified Dev's Home screen, in the menu bar \
            and in Shortcuts. They are left out of the sidebar and of the Cmd+K search panel, \
            which read the same preference. The owner brings a hidden project back by turning on \
            Show hidden projects in the sidebar's filter menu, or you can with project_unhide.

            Hiding a project that is already hidden is not an error and changes nothing. A \
            project Unified Dev does not have is refused rather than added: project_add is what \
            registers a repository.
            """,
        inputSchema: ProjectVisibilityCall.schema(
            "Which project to hide, by the name, path or id project_list reports."
        )
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        await ProjectVisibilityCall.run(request, hidden: true, tool: tool.name, store: store)
    }
}

public struct ProjectUnhideTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.owner]

    public let tool = BridgeTool(
        name: "project_unhide",
        description: """
            Put a hidden project back in Unified Dev's sidebar, in the place in the list it already \
            had. Takes the project's name, its absolute path, or the id project_list prints.

            project_list reports which projects are hidden, so call that first if you do not know \
            which ones to bring back. Showing a project that was never hidden is not an error and \
            changes nothing. A project Unified Dev does not have is refused rather than added: \
            project_add is what registers a repository.
            """,
        inputSchema: ProjectVisibilityCall.schema(
            "Which project to show again, by the name, path or id project_list reports."
        )
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        await ProjectVisibilityCall.run(request, hidden: false, tool: tool.name, store: store)
    }
}

enum ProjectVisibilityCall {
    static func schema(_ description: String) -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "project": .object([
                    "type": .string("string"),
                    "description": .string(description),
                ]),
            ]),
            "required": .array([.string("project")]),
        ])
    }

    static func run(
        _ request: MCPRequest,
        hidden: Bool,
        tool: String,
        store: Store
    ) async -> BridgeToolResult {
        let query = request.stringParam("project")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else {
            return .failure(ProjectHideTrouble.noProjectNamed(tool: tool).sentence)
        }

        do {
            let projects = try await store.repos()
            let outcome = BridgeProjectLookup.find(query, in: projects)
            if let trouble = ProjectHideTrouble.diagnose(
                query: query, outcome: outcome, projects: projects, tool: tool
            ) {
                return .failure(trouble.sentence)
            }
            guard case .found(let project) = outcome else {
                return .failure(ProjectHideTrouble.unknown(
                    query: query, known: projects.map(\.name)
                ).sentence)
            }

            let wasAlready = project.hidden == hidden
            _ = try await store.update(repoID: project.id) { $0.hidden = hidden }

            let visible = ProjectVisibility.listed(try await store.repos(), showingHidden: false)

            return .json(.object([
                "id": .string(project.id.rawValue),
                "name": .string(project.name),
                "path": .string(project.path),
                "hidden": .bool(hidden),
                "state": .string(state(hidden: hidden, wasAlready: wasAlready)),
                "note": .string(
                    note(hidden: hidden, wasAlready: wasAlready, visible: visible.count)
                ),
            ]))
        } catch {
            return .failure(
                ProjectHideTrouble.unexplained(tool: tool, message: error.readableMessage).sentence
            )
        }
    }

    private static func state(hidden: Bool, wasAlready: Bool) -> String {
        switch (hidden, wasAlready) {
        case (true, true): "already_hidden"
        case (true, false): "hidden"
        case (false, true): "already_showing"
        case (false, false): "showing"
        }
    }

    private static func note(hidden: Bool, wasAlready: Bool, visible: Int) -> String {
        guard !wasAlready else {
            return hidden
                ? "Unified Dev was already leaving this project out of the sidebar. Nothing changed."
                : "This project was already showing in Unified Dev's sidebar. Nothing changed."
        }
        guard hidden else {
            return "It is back in Unified Dev's sidebar, in the place in the list it already had. "
                + ProjectVisibility.remainingSentence(visible: visible)
        }
        return "Unified Dev's sidebar and its search panel leave it out now. Nothing stopped and "
            + "nothing was deleted: its workspaces are running exactly as they were and are still "
            + "on Home and in the menu bar. " + ProjectVisibility.remainingSentence(visible: visible)
    }
}
