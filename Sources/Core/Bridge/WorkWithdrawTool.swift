import Foundation

public struct WorkWithdrawTool: BridgeToolHandling {
    public static let name = "work_withdraw"

    public init() {}

    public let roles: Set<BridgeRole> = [.parent, .owner]

    public let tool = BridgeTool(
        name: WorkWithdrawTool.name,
        description: """
            Take back a suggestion you made with work_suggest, by the id it answered with, when it \
            no longer makes sense: you found the work already done, or found that it was wrong. The \
            card stays in this chat, marked as withdrawn by you and with no buttons, so the owner \
            can still read what you had suggested.

            Only a suggestion still waiting for the owner can be withdrawn, and only by the chat \
            that made it. One the owner has started or dismissed is theirs, and the answer says so.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "suggestion_id": .object([
                    "type": .string("string"),
                    "description": .string("The id work_suggest answered with."),
                ]),
            ]),
            "required": .array([.string("suggestion_id")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let sessionID = identity.sessionID else {
            return .failure(WorkSuggestTrouble.noChat(tool: Self.name).sentence)
        }
        guard let raw = AgentStartTool.text(request.stringParam("suggestion_id")) else {
            return .failure(WorkSuggestTrouble.noSuggestionID.sentence)
        }

        do {
            switch try await store.withdrawWorkSuggestion(id: WorkSuggestionID(raw), by: sessionID) {
            case .withdrawn(let suggestion):
                return .json(Self.answer(suggestion, note: "The card now says you withdrew it. Nothing had started."))
            case .alreadyDecided(let suggestion) where suggestion.state == .withdrawn:
                return .json(Self.answer(suggestion, note: "It was already withdrawn. Nothing changed."))
            case .alreadyDecided(let suggestion):
                return .failure(WorkSuggestTrouble.alreadyDecided(suggestion.state).sentence)
            case .notYours:
                return .failure(WorkSuggestTrouble.notYours.sentence)
            case .missing:
                return .failure(WorkSuggestTrouble.unknownSuggestion(raw).sentence)
            }
        } catch {
            return .failure(WorkSuggestTrouble.unexplained(tool: Self.name, error.readableMessage).sentence)
        }
    }

    private static func answer(_ suggestion: WorkSuggestion, note: String) -> JSONValue {
        .object([
            "suggestion_id": .string(suggestion.id.rawValue),
            "state": .string("withdrawn"),
            "note": .string(note),
        ])
    }
}
