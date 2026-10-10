import Foundation

public struct BrowserWaitTool: BridgeToolHandling {
    private let drive: BrowserPaneCommanding

    public init(_ drive: @escaping BrowserPaneCommanding) {
        self.drive = drive
    }

    public let tool = BridgeTool(
        name: BrowserPaneToolName.wait,
        description: """
            Wait for the page in a browser pane the person has open to settle after something you \
            did. Pass 'text' to wait for a phrase to appear in the page, or 'gone' to wait for \
            one to leave it, or neither to wait for the load to finish. One at a time.

            'seconds' is how long to wait at most, between \(BrowserWaitSeconds.minimum) and \
            \(BrowserWaitSeconds.maximum). Leave it out to wait \(BrowserWaitSeconds.fallback). A \
            page that takes longer than \(BrowserWaitSeconds.maximum) seconds is one to tell the \
            person about rather than to sit on.

            \(BrowserPaneArgument.sentence)

            The answer says which of the two happened: the condition was met, with how long it \
            took, or the time ran out. Running out is an answer and not a failure, and either \
            way waiting is not approval for anything else: the next thing you do asks for itself.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "text": .object([
                    "type": .string("string"),
                    "description": .string("A phrase to wait for the page to show."),
                ]),
                "gone": .object([
                    "type": .string("string"),
                    "description": .string("A phrase to wait for the page to stop showing."),
                ]),
                "seconds": .object([
                    "type": .string("integer"),
                    "description": .string(
                        "How long to wait at most, between \(BrowserWaitSeconds.minimum) and "
                            + "\(BrowserWaitSeconds.maximum)."
                    ),
                ]),
                "browser": BrowserPaneArgument.schema,
            ]),
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
            BrowserWaitCondition.parse(
                text: request.stringParam("text"), gone: request.stringParam("gone")
            ).flatMap { condition in
                BrowserWaitSeconds.parse(request.param("seconds"))
                    .map { .wait(browser, condition, seconds: $0) }
            }
        }
    }
}
