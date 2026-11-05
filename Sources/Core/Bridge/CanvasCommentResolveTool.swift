import Foundation

public enum CanvasCommentResolveToolName {
    public static let resolve = "canvas_comment_resolve"
}

public typealias CanvasCommentResolving = @MainActor @Sendable (
    _ order: CanvasCommentResolveOrder, _ workspaceID: WorkspaceID
) async -> CanvasCommentResolveOutcome

public struct CanvasCommentResolveTool: BridgeToolHandling {
    private let resolving: CanvasCommentResolving

    public init(_ resolving: @escaping CanvasCommentResolving) { self.resolving = resolving }

    public let roles = BridgeWorkspaceScope.roles
    public let tool = BridgeTool(
        name: CanvasCommentResolveToolName.resolve,
        description: """
            Answer a comment the person left on a canvas document in this workspace. Every comment you \
            are handed asks for this call once you have dealt with it: outcome 'resolved' with a \
            sentence saying what you did, or outcome 'declined' with the reason you will not do it. \
            A comment you leave unanswered when the turn ends is shown to the person as unanswered. \
            Works whether or not the canvas is open in a tab, and does not open or focus the tab.

            Only the chat a comment was sent to can answer it. One sent to another chat, or not sent \
            to any chat yet, is refused and left as it is, even though canvas_read lists it. A comment \
            already answered is refused and keeps its answer. A canvas that is corrupt, saved by a \
            newer Unified Dev, no longer on disk or with saving paused because the file changed is \
            refused with the reason: the person has to settle that in the tab first.

            An answer is not an undo step for the person. The answer says whether it reached the \
            file; if 'saved' is false, do not commit the file as it is. A project's orchestrator \
            workspace may answer too, since this writes the comment's state and nothing the person drew.

            'path' is workspace-relative or absolute and must name a canvas document inside this \
            workspace.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The canvas document holding the comment, inside this workspace."),
                ]),
                "commentID": .object([
                    "type": .string("string"),
                    "description": .string("The comment id from the message you were sent."),
                ]),
                "outcome": .object([
                    "type": .string("string"),
                    "enum": .array([.string("resolved"), .string("declined")]),
                    "description": .string("'resolved' if you dealt with it, 'declined' if you will not."),
                ]),
                "response": .object([
                    "type": .string("string"),
                    "description": .string("What you did, or why you will not. The person reads this."),
                ]),
            ]),
            "required": .array([.string("path"), .string("commentID"), .string("outcome"), .string("response")]),
        ])
    )

    public func call(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: CanvasCommentResolveToolName.resolve, doing: "answers a comment in")
            )
        }
        guard let path = Self.text("path", in: request) else {
            return .failure("canvas_comment_resolve needs a non-empty 'path'.")
        }
        guard let comment = Self.text("commentID", in: request) else {
            return .failure("canvas_comment_resolve needs 'commentID', the comment id from the message you were sent.")
        }
        guard let state = Self.state(named: Self.text("outcome", in: request)) else {
            return .failure("'outcome' is 'resolved' or 'declined'.")
        }
        guard let response = Self.text("response", in: request) else {
            return .failure("canvas_comment_resolve needs a 'response': what you did, or why you will not. The person reads it.")
        }
        let order = CanvasCommentResolveOrder(
            path: path, commentID: CanvasCommentID(comment), state: state, response: response, caller: identity.sessionID
        )
        switch await resolving(order, workspaceID) {
        case .refused(let sentence): return .failure(sentence)
        case .resolved(let result): return Self.answer(result)
        }
    }

    private static func text(_ name: String, in request: MCPRequest) -> String? {
        let trimmed = request.stringParam(name)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func state(named name: String?) -> CanvasComment.State? {
        switch name {
        case "resolved": .resolved
        case "declined": .declined
        default: nil
        }
    }

    private static func answer(_ result: CanvasCommentResolveResult) -> BridgeToolResult {
        var fields: [String: JSONValue] = [
            "resolved": .bool(true),
            "state": .string(result.state.rawValue),
            "saved": .bool(result.disk == .saved),
        ]
        switch result.disk {
        case .saved:
            return .json(.object(fields))
        case .notSaved(let reason):
            fields["warning"] = .string(
                "The answer is in the open canvas but is not on disk (\(reason)). Do not commit the file as it is; "
                    + "it will be saved when the person resolves this in the tab."
            )
            return .json(.object(fields))
        case .replaced:
            fields["resolved"] = .bool(false)
            fields["warning"] = .string(
                "The file changed on disk while this was being saved, so Unified Dev reloaded it and this answer no longer exists. "
                    + "Read the canvas again and decide again."
            )
            return BridgeToolResult(text: BridgeToolResult.json(.object(fields)).text, isError: true)
        }
    }
}
