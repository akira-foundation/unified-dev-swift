import Foundation

public typealias PaneRenaming = @Sendable (String, PaneKind?, WorkspaceID) async -> PaneOutcome

public struct PaneRenameOrder: Sendable, Equatable {
    public var title: String

    public var kind: PaneKind?

    public init(title: String, kind: PaneKind? = nil) {
        self.title = title
        self.kind = kind
    }
}

public struct PaneRenameTool: BridgeToolHandling {
    private let rename: PaneRenaming

    public init(_ rename: @escaping PaneRenaming) {
        self.rename = rename
    }

    public let roles = BridgeWorkspaceScope.roles

    public let tool = BridgeTool(
        name: "pane_rename",
        description: """
            Rename a pane in the workspace you are in. Use it when a tab is now about something \
            nameable, a terminal running one long build or a browser sitting on one page, so the \
            reader can find it again among tabs that are otherwise all called the same thing.

            'title' is what to call it and is required. 'kind' is one of \(PaneOrder.kindList) and \
            renames the pane showing that; leave it out to rename the pane the reader is focused \
            on.

            It renames one pane in your own workspace and takes no workspace argument. It is not \
            destructive: the reader can rename it back by double clicking the tab.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("What to call the pane."),
                ]),
                "kind": .object([
                    "type": .string("string"),
                    "enum": .array(PaneKind.allCases.map { .string($0.rawValue) }),
                    "description": .string(
                        "Which pane to rename. Omit for the one the reader is focused on."
                    ),
                ]),
            ]),
            "required": .array([.string("title")]),
        ])
    )

    static func parse(title rawTitle: String?, kind rawKind: String?)
        -> Result<PaneRenameOrder, PaneRefusal> {
        guard let title = PaneOrder.name(from: rawTitle) else {
            return .failure(
                PaneRefusal(
                    "pane_rename needs a 'title' to give the pane. A blank one would leave a tab "
                        + "the reader cannot tell from any other."
                )
            )
        }

        let raw = rawKind?.trimmingCharacters(in: .whitespaces)
        guard let raw, !raw.isEmpty else { return .success(PaneRenameOrder(title: title)) }
        guard let kind = PaneKind(rawValue: raw) else {
            return .failure(
                PaneRefusal("Unified Dev has no pane called '\(raw)'. It opens \(PaneOrder.kindList).")
            )
        }
        return .success(PaneRenameOrder(title: title, kind: kind))
    }

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: "pane_rename", doing: "renames a pane in")
            )
        }

        switch Self.parse(
            title: request.stringParam("title"), kind: request.stringParam("kind")
        ) {
        case .failure(let refusal):
            return .failure(refusal.sentence)
        case .success(let order):
            switch await rename(order.title, order.kind, workspaceID) {
            case .opened(let sentence): return BridgeToolResult(text: sentence)
            case .refused(let refusal): return .failure(refusal)
            }
        }
    }
}
