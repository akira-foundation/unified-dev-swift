import Foundation

public typealias PaneOpening = @Sendable (PaneOrder, WorkspaceID) async -> PaneOutcome

public struct PaneOpenTool: BridgeToolHandling {
    private let open: PaneOpening

    public init(_ open: @escaping PaneOpening) {
        self.open = open
    }

    public let roles = BridgeWorkspaceScope.roles

    public let tool = BridgeTool(
        name: "pane_open",
        description: """
            Create a NEW TAB in the top tab strip, containing a chat, terminal or browser.
            A tab is a switchable arrangement; a pane is a visible region inside that arrangement.
            Use pane_open when the person asks for a "new tab" or "separate tab". For "add a pane", \
            "split pane in this chat", or something "next to this chat", use pane_split instead: \
            it keeps this conversation visible and adds a pane on its right by default.

            'kind' is one of \(PaneOrder.kindList). 'url' is for a browser and is optional. \
            'title' is what the tab is called and is optional: pass one when you know what the \
            pane is for, because four tabs called Terminal are four a reader cannot tell apart. \
            'focus' decides whether the new tab is brought to the front, and defaults to true: \
            pass false when you are opening something to be useful later and the reader is in the \
            middle of something now.

            It opens in your own workspace and takes no workspace argument. It is not \
            destructive: the reader can close the tab.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "kind": .object([
                    "type": .string("string"),
                    "enum": .array(PaneKind.allCases.map { .string($0.rawValue) }),
                    "description": .string("What to open."),
                ]),
                "url": .object([
                    "type": .string("string"),
                    "description": .string("Where a browser pane should start. Browser only."),
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What to call the tab. Leave it out for the strip's own numbering."
                    ),
                ]),
                "focus": .object([
                    "type": .string("boolean"),
                    "description": .string(
                        "Whether to bring the new tab to the front. Defaults to true."
                    ),
                ]),
            ]),
            "required": .array([.string("kind")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: "pane_open", doing: "opens a pane in")
            )
        }
        switch PaneOrder.parse(
            kind: request.stringParam("kind"),
            url: request.stringParam("url"),
            focus: request.param("focus"),
            title: request.stringParam("title"),
            tool: "pane_open"
        ) {
        case .refused(let refusal):
            return .failure(refusal)
        case .order(let order):
            switch await open(order, workspaceID) {
            case .opened(let sentence): return BridgeToolResult(text: sentence)
            case .refused(let refusal): return .failure(refusal)
            }
        }
    }
}
