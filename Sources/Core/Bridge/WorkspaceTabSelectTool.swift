import Foundation

public typealias WorkspaceTabSelecting =
    @Sendable (WorkspaceTabChoice, WorkspaceID) async -> WorkspaceTabSelection

public struct WorkspaceTabSelectTool: BridgeToolHandling {
    private let select: WorkspaceTabSelecting

    public init(_ select: @escaping WorkspaceTabSelecting) {
        self.select = select
    }

    public let roles = BridgeWorkspaceScope.roles

    public let tool = BridgeTool(
        name: "workspace_tab_select",
        description: """
            Bring one tab of your workspace's centre column to the front, which is what clicking \
            it in the strip does.

            Name it with 'tab', the number workspace_tabs prints, or with 'title', the name the \
            strip shows. One of the two and not both. Numbers move as tabs are opened and closed, \
            so call workspace_tabs in the same turn rather than reusing a number from earlier.

            It only ever selects a tab that is already open: it will not create one, and a name \
            nothing answers to is refused with the list of tabs there are. pane_open is what opens \
            a new tab.

            A tab with a browser in it is refused: bringing it forward would load the page from \
            the person's own browser without asking them, so ask them to click it instead.

            Selecting a chat also makes it the workspace's active conversation, exactly as \
            clicking it would. The person may be reading or typing in the tab that is in front, so \
            ask before pulling them out of it unless they asked you to.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "tab": .object([
                    "type": .string("integer"),
                    "description": .string(
                        "Which tab, as workspace_tabs numbers them, counting from 1 along the "
                            + "strip."
                    ),
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The tab's name as the strip shows it. Case does not matter. Refused when "
                            + "two tabs share the name, so pass 'tab' for those."
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
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: "workspace_tab_select", doing: "acts on")
            )
        }

        let choice: WorkspaceTabChoice
        switch WorkspaceTabChoice.parse(
            number: request.param("tab"), title: request.param("title")
        ) {
        case .failure(let refusal): return .failure(refusal.sentence)
        case .success(let parsed): choice = parsed
        }

        switch await select(choice, workspaceID) {
        case .selected(let sentence): return BridgeToolResult(text: sentence)
        case .refused(let sentence): return .failure(sentence)
        }
    }
}
