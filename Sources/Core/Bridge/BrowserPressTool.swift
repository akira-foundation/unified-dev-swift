import Foundation

public struct BrowserPressTool: BridgeToolHandling {
    private let drive: BrowserPaneCommanding

    public init(_ drive: @escaping BrowserPaneCommanding) {
        self.drive = drive
    }

    public let tool = BridgeTool(
        name: BrowserPaneToolName.press,
        description: """
            Send one key to the page in a browser pane the person has open. It takes 'enter', \
            'tab', 'escape', 'backspace', 'up', 'down', 'left' and 'right', one at a time, and \
            nothing else: there are no modifier combinations here, and a shortcut of the \
            person's own is theirs to press.

            Pass 'element' to aim the key at one element, which is focused first. Leave it out \
            and the key goes to whatever on the page has focus.

            \(BrowserElementArgument.sentence)

            \(BrowserPaneArgument.sentence)

            The key is a synthetic event, so isTrusted is false on it. A form that submits on a \
            real Enter may not submit on this one, and that is a limit rather than a fault: \
            browser_click on the submit button is the way round it.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "key": .object([
                    "type": .string("string"),
                    "enum": .array(BrowserKeyPress.allCases.map { .string($0.rawValue) }),
                    "description": .string("Which key to send."),
                ]),
                "element": BrowserElementArgument.schema,
                "browser": BrowserPaneArgument.schema,
            ]),
            "required": .array([.string("key")]),
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
            BrowserKeyPress.parse(request.stringParam("key")).flatMap { key in
                BrowserElementArgument
                    .parseOptional(request.param("element"), tool: BrowserPaneToolName.press)
                    .map { .press(browser, key, $0) }
            }
        }
    }
}
