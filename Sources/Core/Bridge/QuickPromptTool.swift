import Foundation

enum QuickPromptCall {
    static func library(_ store: Store) async throws -> [QuickPrompt] {
        try await store.seedQuickPrompts()
    }

    struct Draft: Sendable, Equatable {
        var name: String
        var symbol: String
        var text: String
    }

    struct Edit: Sendable, Equatable {
        var name: String?
        var symbol: String?
        var text: String?

        var changed: [String] {
            var fields: [String] = []
            if name != nil { fields.append("name") }
            if symbol != nil { fields.append("symbol") }
            if text != nil { fields.append("text") }
            return fields
        }
    }

    static func draft(name: String?, symbol: String?, text: String?) -> Result<Draft, QuickPromptTrouble> {
        let body = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return .failure(.noText) }

        let chosenMark: String
        switch mark(symbol) {
        case .failure(let trouble): return .failure(trouble)
        case .success(let resolved): chosenMark = resolved ?? QuickPrompt.defaultSymbol
        }

        return .success(
            Draft(
                name: (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                symbol: chosenMark,
                text: body
            )
        )
    }

    static func edit(name: String?, symbol: String?, text: String?) -> Result<Edit, QuickPromptTrouble> {
        var edit = Edit()

        if let name {
            edit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let text {
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return .failure(.blankText(field: "text")) }
            edit.text = body
        }

        switch mark(symbol) {
        case .failure(let trouble): return .failure(trouble)
        case .success(let resolved): edit.symbol = resolved
        }

        guard !edit.changed.isEmpty else { return .failure(.nothingToChange) }
        return .success(edit)
    }

    static func mark(_ symbol: String?) -> Result<String?, QuickPromptTrouble> {
        guard let symbol else { return .success(nil) }
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .success(nil) }
        guard QuickPromptMark(stored: trimmed).stored == trimmed else {
            return .failure(.unknownSymbol(trimmed))
        }
        return .success(trimmed)
    }

    static func find(
        id raw: String?, in prompts: [QuickPrompt], tool: String
    ) -> Result<QuickPrompt, QuickPromptTrouble> {
        let id = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return .failure(.noID(tool: tool)) }
        guard !prompts.isEmpty else { return .failure(.emptyLibrary(tool: tool)) }
        guard let found = prompts.first(where: { $0.id.rawValue == id }) else {
            return .failure(.unknownID(id: id, known: prompts))
        }
        return .success(found)
    }

    static func json(_ prompt: QuickPrompt) -> JSONValue {
        .object([
            "id": .string(prompt.id.rawValue),
            "name": .string(prompt.name),
            "shown_as": .string(prompt.resolvedName),
            "symbol": .string(prompt.symbol),
            "text": .string(prompt.text),
            "sends_immediately": .bool(prompt.sendsImmediately),
            "opens_new_chat": .bool(prompt.opensNewChat),
            "sort_order": .integer(prompt.sortOrder),
            "created_at": .string(prompt.createdAt.formatted(.iso8601)),
        ])
    }

    static let panelSentence =
        "Quick prompts are global: one library, in the panel beside the composer in every "
            + "workspace, rather than anything belonging to a project or a workspace."
}

public struct QuickPromptListTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.workspace, .owner]

    public let tool = BridgeTool(
        name: "quick_prompt_list",
        description: """
            The owner's quick prompts: the few lines they keep typing again, kept by Unified Dev and put \
            back into the composer from the panel beside it. Each one carries its id, its name, \
            the mark drawn down the left of its row, and the whole of its text.

            Call this before quick_prompt_update or quick_prompt_delete, because the id it prints \
            is the only thing either of those takes. It is also what stops you writing a second \
            copy of a prompt the owner already has.

            \(QuickPromptCall.panelSentence)

            It reads. The only thing it can ever write is Unified Dev's own built-in prompt, on a copy \
            of Unified Dev whose quick prompt panel has never been opened, which is what opening the \
            panel would have done anyway.
            """,
        inputSchema: BridgeTool.noArguments
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        do {
            let prompts = try await QuickPromptCall.library(store)
            return .json(.object([
                "count": .integer(prompts.count),
                "prompts": .array(prompts.map(QuickPromptCall.json)),
                "note": .string(
                    prompts.isEmpty
                        ? "Unified Dev has no quick prompts. quick_prompt_create writes one."
                        : QuickPromptCall.panelSentence
                ),
            ]))
        } catch {
            return .failure(
                QuickPromptTrouble.unexplained(
                    tool: tool.name, message: error.readableMessage
                ).sentence
            )
        }
    }
}

public struct QuickPromptCreateTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.workspace, .owner]

    public let tool = BridgeTool(
        name: "quick_prompt_create",
        description: """
            Write a new quick prompt into the owner's library, so it is in the panel beside the \
            composer from then on.

            Call it when the owner asks you to save something as a quick prompt, and not on your \
            own initiative. This is their own list in their own words, and a row they did not ask \
            for is one they have to find and delete.

            'text' is the prompt itself and is required: it is what goes into the composer when \
            the row is picked. 'name' is what the row is called and is optional; leave it out and \
            the row shows the start of the text instead. 'symbol' is the mark down the left of \
            the row: one emoji, or an SF Symbol name Unified Dev's own picker offers. Leave it out for \
            Unified Dev's default.

            \(QuickPromptCall.panelSentence)

            It adds a row and changes nothing that is already there. The owner takes it away again \
            from the panel, or you can with quick_prompt_delete.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "text": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The words the prompt puts in the composer. It cannot be blank."
                    ),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What the row is called. Leave it out to show the start of the text."
                    ),
                ]),
                "symbol": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The mark down the left of the row: one emoji, or an SF Symbol name from "
                            + "Unified Dev's picker. Leave it out for Unified Dev's default."
                    ),
                ]),
            ]),
            "required": .array([.string("text")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        let draft: QuickPromptCall.Draft
        switch QuickPromptCall.draft(
            name: request.stringParam("name"),
            symbol: request.stringParam("symbol"),
            text: request.stringParam("text")
        ) {
        case .failure(let trouble): return .failure(trouble.sentence)
        case .success(let read): draft = read
        }

        do {
            _ = try await QuickPromptCall.library(store)
            let written = try await store.insert(
                QuickPrompt(name: draft.name, symbol: draft.symbol, text: draft.text)
            )
            var answer = QuickPromptCall.json(written)
            if case .object(var fields) = answer {
                fields["note"] = .string(
                    "It is in the quick prompt panel in every workspace's composer now. Nothing "
                        + "else changed. quick_prompt_delete removes it again, and there is no "
                        + "undo on that."
                )
                answer = .object(fields)
            }
            return .json(answer)
        } catch {
            return .failure(
                QuickPromptTrouble.unexplained(
                    tool: tool.name, message: error.readableMessage
                ).sentence
            )
        }
    }
}

public struct QuickPromptUpdateTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.owner]

    public let tool = BridgeTool(
        name: "quick_prompt_update",
        description: """
            Change a quick prompt the owner already has, named by the id quick_prompt_list prints.

            Partial, so pass only what you are changing. 'name', 'symbol' and 'text' are each \
            optional and whatever you leave out keeps the value it already has: changing the name \
            is a call with 'id' and 'name' and nothing else, and it does not touch the text. \
            Passing 'name' as an empty string clears the name, and the row goes back to showing \
            the start of its text. 'text' cannot be blank, because a prompt with no words in it \
            inserts nothing. A call that names no field at all is refused rather than treated as \
            a change of nothing.

            There is no undo. What you overwrite was written by hand and Unified Dev keeps no copy of \
            it, so read the prompt with quick_prompt_list first and change what the owner asked \
            you to change and nothing else.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("Which prompt, by the id quick_prompt_list prints."),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string(
                        "A new name for the row. Leave it out to keep the one it has; pass an "
                            + "empty string to clear it."
                    ),
                ]),
                "symbol": .object([
                    "type": .string("string"),
                    "description": .string(
                        "A new mark: one emoji, or an SF Symbol name from Unified Dev's picker. Leave "
                            + "it out to keep the one it has."
                    ),
                ]),
                "text": .object([
                    "type": .string("string"),
                    "description": .string(
                        "New words for the composer. Leave it out to keep the ones it has. It "
                            + "cannot be blank."
                    ),
                ]),
            ]),
            "required": .array([.string("id")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        let edit: QuickPromptCall.Edit
        switch QuickPromptCall.edit(
            name: request.stringParam("name"),
            symbol: request.stringParam("symbol"),
            text: request.stringParam("text")
        ) {
        case .failure(let trouble): return .failure(trouble.sentence)
        case .success(let read): edit = read
        }

        do {
            let prompts = try await QuickPromptCall.library(store)
            let target: QuickPrompt
            switch QuickPromptCall.find(
                id: request.stringParam("id"), in: prompts, tool: tool.name
            ) {
            case .failure(let trouble): return .failure(trouble.sentence)
            case .success(let found): target = found
            }

            let changed = try await store.update(quickPromptID: target.id) { prompt in
                if let name = edit.name { prompt.name = name }
                if let symbol = edit.symbol { prompt.symbol = symbol }
                if let text = edit.text { prompt.text = text }
            }
            guard let changed else {
                return .failure(
                    QuickPromptTrouble.unknownID(id: target.id.rawValue, known: prompts).sentence
                )
            }

            var answer = QuickPromptCall.json(changed)
            if case .object(var fields) = answer {
                fields["changed"] = .array(edit.changed.map { .string($0) })
                fields["note"] = .string(
                    "The prompt above is the whole row as it stands now. Anything not in "
                        + "'changed' is untouched, and there is no undo on what was."
                )
                answer = .object(fields)
            }
            return .json(answer)
        } catch {
            return .failure(
                QuickPromptTrouble.unexplained(
                    tool: tool.name, message: error.readableMessage
                ).sentence
            )
        }
    }
}

public struct QuickPromptDeleteTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.owner]

    public let tool = BridgeTool(
        name: "quick_prompt_delete",
        description: """
            Remove a quick prompt from the owner's library, named by the id quick_prompt_list \
            prints.

            There is no undo and Unified Dev keeps no copy. The answer repeats the whole prompt, its \
            name, its mark and its text, so quick_prompt_create can write it back if this turns \
            out to have been the wrong one. That is the only way back, and it comes back as an \
            ordinary prompt: if sends_immediately or opens_new_chat was set, say so to the owner, \
            because no tool can set those and only he can turn them on again.

            Deleting one of Unified Dev's own built-in prompts is a deletion like any other: it stays \
            deleted, and no later launch and no later version of Unified Dev puts it back.

            Only call this when the owner has said to delete that prompt. Never as tidying up, and \
            never on a prompt you did not just read.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Which prompt to delete, by the id quick_prompt_list prints."
                    ),
                ]),
            ]),
            "required": .array([.string("id")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        do {
            let prompts = try await QuickPromptCall.library(store)
            let target: QuickPrompt
            switch QuickPromptCall.find(
                id: request.stringParam("id"), in: prompts, tool: tool.name
            ) {
            case .failure(let trouble): return .failure(trouble.sentence)
            case .success(let found): target = found
            }

            try await store.deleteQuickPrompt(id: target.id)

            var answer = QuickPromptCall.json(target)
            if case .object(var fields) = answer {
                fields["deleted"] = .bool(true)
                fields["remaining"] = .integer(prompts.count - 1)
                fields["note"] = .string(
                    "That prompt is gone from the panel and there is no undo. The whole of it is "
                        + "above: quick_prompt_create writes it back if this was the wrong one. "
                        + "If it was one Unified Dev shipped with, it stays deleted and no later "
                        + "version puts it back."
                )
                answer = .object(fields)
            }
            return .json(answer)
        } catch {
            return .failure(
                QuickPromptTrouble.unexplained(
                    tool: tool.name, message: error.readableMessage
                ).sentence
            )
        }
    }
}
