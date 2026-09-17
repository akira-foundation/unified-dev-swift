import Foundation

public typealias Revealing = @Sendable (RevealPlan) async -> RevealOutcome

public struct RevealTool: BridgeToolHandling {
    private let reveal: Revealing

    public init(_ reveal: @escaping Revealing) {
        self.reveal = reveal
    }

    public let roles: Set<BridgeRole> = [.owner]

    public let tool = BridgeTool(
        name: "reveal",
        description: """
            Point Unified Dev's window at something, exactly as clicking it in the sidebar would.

            Either name one workspace with 'workspace', or leave that out and narrow Home with \
            'project', 'scope' and 'search'. Not both: asking for a workspace and a Home narrowing \
            in the same call is refused rather than one of them quietly winning.

            It only ever selects what is already there. A name nothing answers to is refused with \
            the list of names there are; it will not create a workspace, and workspace_start is \
            what does that.

            To archive a workspace the owner has selected for cleanup, use workspace_archive.

            It changes what the person is looking at, so ask first if they are in the middle of \
            reading something.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "workspace": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Which workspace to show, by name or by the id workspace_list prints. "
                            + "Case does not matter. Refused when two workspaces share a name, so "
                            + "pass the id for those. Cannot be combined with the three below."
                    ),
                ]),
                "project": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Narrow Home to one project, by name or by path, as project_list prints "
                            + "them."
                    ),
                ]),
                "scope": .object([
                    "type": .string("string"),
                    "enum": .array(RevealChoice.offered.map { .string($0.rawValue) }),
                    "description": .string(
                        "Which of Home's chips to light: all, needsYou, running, live or "
                            + "archived. Leaving it out shows everything, archived work included, "
                            + "which is not what Home rests on when a person opens it themselves."
                    ),
                ]),
                "search": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What to type into Home's search field. It matches workspace names, "
                            + "branches, projects and what agents have said."
                    ),
                ]),
            ]),
            "required": .array([]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        let order: RevealOrder
        switch RevealChoice.parse(
            workspace: request.param("workspace"),
            project: request.param("project"),
            scope: request.param("scope"),
            search: request.param("search")
        ) {
        case .failure(let refusal): return .failure(refusal.sentence)
        case .success(let parsed): order = parsed
        }

        let workspaces = (try? await store.workspaces()) ?? []
        let projects = (try? await store.repos()) ?? []

        let resolved: RevealPlan
        switch RevealChoice.resolve(order, workspaces: workspaces, projects: projects) {
        case .failure(let refusal): return .failure(refusal.sentence)
        case .success(let found): resolved = found
        }

        switch await reveal(resolved) {
        case .revealed(let sentence): return BridgeToolResult(text: sentence)
        case .refused(let sentence): return .failure(sentence)
        }
    }
}
