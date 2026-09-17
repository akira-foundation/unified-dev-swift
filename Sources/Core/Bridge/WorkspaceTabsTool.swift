import Foundation

public typealias WorkspaceTabListing = @Sendable (WorkspaceID) async -> WorkspaceTabCensus?

public struct WorkspaceTabsTool: BridgeToolHandling {
    private let census: WorkspaceTabListing

    public init(_ census: @escaping WorkspaceTabListing) {
        self.census = census
    }

    public let roles = BridgeWorkspaceScope.roles

    public let tool = BridgeTool(
        name: "workspace_tabs",
        description: """
            A tab is an entry in the top strip that owns an arrangement of one or more panes. \
            Panes are the regions visible together inside that tab. Use pane_split for "add a \
            pane" or "next to this chat"; use pane_open for a separate new tab.

            The tab strip of the workspace you are in, left to right: what each tab is, what the \
            person sees it called, which one is in front, and one true thing about what is in it.

            A chat says which agent drives it, whether a turn is running and how many messages it \
            holds. A review says which file it is showing. A terminal says the directory its shell \
            was started in and whether a shell has been started at all. A browser says where it is \
            pointed and carries the number the browser_ tools take. The notes say how long they \
            are and never what they say.

            A tab somebody has split also lists what it has absorbed. Use pane_list when you want \
            every pane flattened rather than the strip.

            'tab' is a place in the strip counting from 1 and it moves as tabs are opened, closed \
            and dragged, so call this again before acting on a number. workspace_tab_select takes \
            either that number or the title. Use chat_read with a chat title to read its messages,
            or chat_list for IDs when titles are shared.

            It reads your own workspace and takes no arguments. It runs no command and fetches no \
            page: a terminal's directory is where its shell started, not where it is now, and \
            nothing here is the contents of a page, a diff or a note.
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
                BridgeWorkspaceScope.refusal(tool: "workspace_tabs", doing: "lists the tabs of")
            )
        }
        guard let census = await census(workspaceID) else {
            return .failure(WorkspaceTabTrouble.noWorkspace)
        }
        return .json(census.json)
    }
}

public enum WorkspaceTabTrouble {
    public static let noWorkspace =
        "That workspace is not open in Unified Dev any more, so its tabs cannot be reached."
}
