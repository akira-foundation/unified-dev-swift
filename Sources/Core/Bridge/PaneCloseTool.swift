import Foundation

public typealias PaneClosing = @Sendable (PaneKind?, WorkspaceID) async -> PaneOutcome

public struct PaneCloseTool: BridgeToolHandling {
    private let close: PaneClosing

    public init(_ close: @escaping PaneClosing) {
        self.close = close
    }

    public let roles = BridgeWorkspaceScope.roles

    public let tool = BridgeTool(
        name: "pane_close",
        description: """
            Close a pane in the workspace you are in. Use it when you opened something to show \
            the person and it has served its purpose, so they are not left tidying up after you.

            'kind' is one of \(PaneOrder.kindList) and closes the pane showing that. Leave it out \
            to close the pane the reader is focused on.

            It refuses rather than leaving an empty window: the last pane standing stays. It will \
            not close the changed files or the notes, which are the reader's own rather than \
            yours. It closes one pane in your own workspace and takes no workspace argument.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "kind": .object([
                    "type": .string("string"),
                    "enum": .array(PaneKind.allCases.map { .string($0.rawValue) }),
                    "description": .string(
                        "Which pane to close. Omit for the one the reader is focused on."
                    ),
                ]),
            ]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: "pane_close", doing: "closes a pane in")
            )
        }

        var kind: PaneKind?
        if let raw = request.stringParam("kind")?.trimmingCharacters(in: .whitespaces),
           !raw.isEmpty {
            guard let named = PaneKind(rawValue: raw) else {
                return .failure("Unified Dev has no pane called '\(raw)'. It opens \(PaneOrder.kindList).")
            }
            kind = named
        }

        switch await close(kind, workspaceID) {
        case .opened(let sentence): return BridgeToolResult(text: sentence)
        case .refused(let refusal): return .failure(refusal)
        }
    }
}
