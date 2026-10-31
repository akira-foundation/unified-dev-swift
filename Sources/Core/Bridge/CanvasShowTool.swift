import Foundation

public enum CanvasShowToolName {
    public static let show = "canvas_show"
}

public struct CanvasShowOrder: Sendable, Equatable {
    public var path: String
    public var title: String?
    public var focus: Bool
    public var caller: SessionID?

    public init(path: String, title: String? = nil, focus: Bool = true, caller: SessionID? = nil) {
        self.path = path
        self.title = title
        self.focus = focus
        self.caller = caller
    }
}

public enum CanvasShowOutcome: Sendable, Equatable {
    case shown(String)
    case refused(String)
}

public typealias CanvasShowing = @MainActor @Sendable (
    _ order: CanvasShowOrder, _ workspaceID: WorkspaceID
) async -> CanvasShowOutcome

public struct CanvasShowTool: BridgeToolHandling {
    private let show: CanvasShowing

    public init(_ show: @escaping CanvasShowing) { self.show = show }

    public let roles = BridgeWorkspaceScope.roles
    public let tool = BridgeTool(
        name: CanvasShowToolName.show,
        description: """
            Show a file from this workspace in its canvas, a tab beside the chat where the person \
            can read it as a page. Use it when what you have to say is a document: an HTML page \
            you wrote, a Markdown report, an SVG diagram or a PNG, JPEG, GIF or WebP image. HTML is \
            shown as it is and Markdown is rendered.

            Only files inside this workspace's own worktree are accepted. There is one canvas per \
            workspace: calling this again swaps the file it shows rather than opening another \
            tab. The page reloads by itself when the file changes on disk, so keep editing the \
            file instead of calling this again. The canvas has no network: a page cannot load \
            anything from the internet.

            'path' is workspace-relative or absolute. 'title' is an optional tab name. 'focus' \
            defaults to true and brings the canvas to the front; pass false when the person is \
            in the middle of something else and should not be pulled away from it.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The file to show, inside this workspace."),
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("An optional name for the canvas tab."),
                ]),
                "focus": .object([
                    "type": .string("boolean"),
                    "description": .string(
                        "Bring the canvas to the front. Defaults to true."
                    ),
                ]),
            ]),
            "required": .array([.string("path")]),
        ])
    )

    public func call(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: CanvasShowToolName.show, doing: "shows a file in")
            )
        }
        let path = request.stringParam("path")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else { return .failure("canvas_show needs a non-empty 'path'.") }
        let title = request.stringParam("title")?.trimmingCharacters(in: .whitespacesAndNewlines)

        let focus: Bool
        switch request.param("focus") {
        case .none, .null: focus = true
        case .bool(let value)?: focus = value
        default:
            return .failure("'focus' is true or false. Leave it out to bring the canvas to the front.")
        }

        let order = CanvasShowOrder(
            path: path,
            title: title?.isEmpty == true ? nil : title,
            focus: focus,
            caller: identity.sessionID
        )
        switch await show(order, workspaceID) {
        case .shown(let sentence): return BridgeToolResult(text: sentence)
        case .refused(let sentence): return .failure(sentence)
        }
    }
}
