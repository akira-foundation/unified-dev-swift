import Foundation

public struct BrowserClickTool: BridgeToolHandling {
    private let drive: BrowserPaneCommanding

    public init(_ drive: @escaping BrowserPaneCommanding) {
        self.drive = drive
    }

    public let tool = BridgeTool(
        name: BrowserPaneToolName.click,
        description: """
            Press one element of the page in a browser pane the person has open: a button, a \
            link, a checkbox, whatever browser_snapshot listed.

            \(BrowserElementArgument.sentence)

            \(BrowserPaneArgument.sentence)

            The press is a synthetic event, so isTrusted is false on it. A page that insists on a \
            real gesture from a person is not fooled by this, and that is a limit rather than a \
            fault.

            Nothing of the page comes back: take another browser_snapshot to see what changed. A \
            press that navigated has killed every reference you were holding.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "element": BrowserElementArgument.schema,
                "browser": BrowserPaneArgument.schema,
            ]),
            "required": .array([.string("element")]),
        ])
    )

    public let roles = BrowserPaneRun.roles

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        await BrowserPaneRun.perform(
            request, as: identity, tool: tool.name, drive: drive
        ) { browser in
            BrowserElementArgument.parse(request.param("element"), tool: BrowserPaneToolName.click)
                .map { .click(browser, $0) }
        }
    }
}
