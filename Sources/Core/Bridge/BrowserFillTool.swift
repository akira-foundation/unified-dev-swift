import Foundation

public struct BrowserFillTool: BridgeToolHandling {
    private let drive: BrowserPaneCommanding

    public init(_ drive: @escaping BrowserPaneCommanding) {
        self.drive = drive
    }

    public let tool = BridgeTool(
        name: BrowserPaneToolName.fill,
        description: """
            Type into one field of the page in a browser pane the person has open. The text \
            replaces whatever the field held, and the page is told the way a typed value tells \
            it: an input event and a change event.

            \(BrowserElementArgument.sentence)

            \(BrowserPaneArgument.sentence)

            A password field is filled like any other, and the answer reports only how many \
            characters went in. Unified Dev never reads a password field back, so you will not \
            see what you wrote there.

            Nothing else of the page comes back. Take another browser_snapshot when what you \
            typed was meant to change the page.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "element": BrowserElementArgument.schema,
                "text": .object([
                    "type": .string("string"),
                    "description": .string("What the field should end up holding."),
                ]),
                "browser": BrowserPaneArgument.schema,
            ]),
            "required": .array([.string("element"), .string("text")]),
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
            BrowserElementArgument.parse(request.param("element"), tool: BrowserPaneToolName.fill)
                .flatMap { reference in
                    BrowserElementArgument.written(request.param("text"))
                        .map { .fill(browser, reference, $0) }
                }
        }
    }
}
