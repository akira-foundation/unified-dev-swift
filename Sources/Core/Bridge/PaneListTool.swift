import Foundation

public typealias PaneListing = @Sendable (WorkspaceID) async -> PaneCensus?

public struct PaneListTool: BridgeToolHandling {
    private let census: PaneListing

    public init(_ census: @escaping PaneListing) {
        self.census = census
    }

    public let roles = BridgeWorkspaceScope.roles

    public let tool = BridgeTool(
        name: "pane_list",
        description: """
            A pane is a visible region inside a tab. One tab can contain several panes shown \
            together; selecting another tab switches the whole arrangement. pane_split adds a \
            pane beside the chat making the request. pane_open creates a separate tab.

            List what the person has open in the workspace you are in: their chats, terminals, \
            browsers, the changed files and the notes. Each pane says what kind it is, what the \
            tab is called, and whether it is in the tab they are looking at right now.

            A browser pane also says where it is pointed and whether it is still loading, and \
            carries the number the browser_ tools take. Call this first whenever you mean to read \
            or drive one of them, because those numbers change as tabs are opened and closed.

            It reads your own workspace and takes no arguments. It reports the tab strip and never \
            the contents of a page: browser_text and browser_screenshot are what read a page.
            """,
        inputSchema: BridgeTool.noArguments
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: "pane_list", doing: "lists the panes of")
            )
        }
        guard let census = await census(workspaceID) else {
            return .failure(
                "That workspace is not open in Unified Dev any more, so there is nothing to list."
            )
        }
        return .json(census.json)
    }
}
