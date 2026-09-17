import Foundation
import Testing
@testable import Core

@Suite("Asking Unified Dev about quick prompts")
struct QuickPromptToolArgumentTests {
    @Test("a create takes the text, and the name and the mark are optional")
    func createTakesTextAndOptionally() throws {
        #expect(
            try QuickPromptCall.draft(name: nil, symbol: nil, text: "Explain this diff.").get()
                == QuickPromptCall.Draft(
                    name: "", symbol: QuickPrompt.defaultSymbol, text: "Explain this diff."
                )
        )
        #expect(
            try QuickPromptCall.draft(
                name: "  Explain  ", symbol: " doc.richtext ", text: "  Explain this diff.  "
            ).get()
                == QuickPromptCall.Draft(
                    name: "Explain", symbol: "doc.richtext", text: "Explain this diff."
                )
        )
    }

    @Test("a create with no text is refused rather than writing an empty row")
    func createNeedsText() {
        for blank in [nil, "", "   ", "\n"] as [String?] {
            guard case .failure(let trouble) = QuickPromptCall.draft(
                name: "Explain", symbol: nil, text: blank
            ) else {
                Issue.record("expected a refusal for \(String(describing: blank))"); return
            }
            #expect(trouble.sentence.contains("'text'"))
            #expect(trouble.sentence.contains("quick_prompt_create"))
        }
    }

    @Test("a create with no name is a row that shows the start of its text")
    func createWithoutAName() {
        let draft = try? QuickPromptCall.draft(name: "   ", symbol: nil, text: "Run the tests.").get()
        #expect(draft?.name == "")
        let prompt = QuickPrompt(name: draft?.name ?? "", text: draft?.text ?? "")
        #expect(prompt.resolvedName == "Run the tests.")
    }

    @Test("a mark Unified Dev cannot draw is refused, with marks that work")
    func anUnknownMarkIsRefused() {
        guard case .failure(let trouble) = QuickPromptCall.mark("sparkle.wand.of.holding") else {
            Issue.record("expected a refusal"); return
        }
        #expect(trouble.sentence.contains("'sparkle.wand.of.holding'"))
        #expect(trouble.sentence.contains("emoji"))
    }

    @Test("every mark the refusal recommends is one Unified Dev can draw")
    func theRecommendedMarksAreReal() {
        let quoted = QuickPromptTrouble.symbolExamples
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '")) }
        #expect(quoted.count == 3)
        for name in quoted {
            #expect(QuickPromptMark(stored: name).stored == name)
        }
    }

    @Test("one emoji is a mark, and so is a symbol name from the picker")
    func emojiAndSymbolsBothWork() throws {
        #expect(try QuickPromptCall.mark("🚀").get() == "🚀")
        #expect(try QuickPromptCall.mark(" hammer ").get() == "hammer")
    }

    @Test("a blank mark is no mark rather than a blank row")
    func aBlankMarkIsNoMark() throws {
        #expect(try QuickPromptCall.mark(nil).get() == nil)
        #expect(try QuickPromptCall.mark("  ").get() == nil)
        let draft = try? QuickPromptCall.draft(name: nil, symbol: "", text: "x").get()
        #expect(draft?.symbol == QuickPrompt.defaultSymbol)
    }

    @Test("an update names only the fields it changes")
    func anUpdateIsPartial() throws {
        #expect(
            try QuickPromptCall.edit(name: " Explain ", symbol: nil, text: nil).get()
                == QuickPromptCall.Edit(name: "Explain")
        )
        #expect(
            try QuickPromptCall.edit(name: nil, symbol: "🚀", text: nil).get().changed == ["symbol"]
        )
        #expect(
            try QuickPromptCall.edit(name: "a", symbol: "🚀", text: "b").get().changed
                == ["name", "symbol", "text"]
        )
    }

    @Test("an empty name clears the name, and an empty text is refused")
    func emptyMeansTwoDifferentThings() throws {
        #expect(try QuickPromptCall.edit(name: "", symbol: nil, text: nil).get() == QuickPromptCall.Edit(name: ""))

        guard case .failure(let trouble) = QuickPromptCall.edit(name: nil, symbol: nil, text: "  ")
        else { Issue.record("expected a refusal"); return }
        #expect(trouble.sentence.contains("'text'"))
        #expect(trouble.sentence.contains("leave"))
    }

    @Test("an update that changes nothing is refused and lists the fields")
    func anUpdateWithNothingInIt() {
        guard case .failure(let trouble) = QuickPromptCall.edit(name: nil, symbol: nil, text: nil)
        else { Issue.record("expected a refusal"); return }
        for field in ["'name'", "'symbol'", "'text'"] {
            #expect(trouble.sentence.contains(field))
        }
    }

    private var library: [QuickPrompt] {
        [
            QuickPrompt(id: QuickPromptID("one"), name: "Explain changes", text: "Explain."),
            QuickPrompt(id: QuickPromptID("two"), name: "", text: "Run make test."),
        ]
    }

    @Test("a prompt is found by the id the listing prints")
    func foundByID() throws {
        #expect(
            try QuickPromptCall.find(id: " one ", in: library, tool: "quick_prompt_delete").get().id
                == QuickPromptID("one")
        )
    }

    @Test("a name is not an id, and the refusal says where ids come from")
    func aNameIsNotAnID() {
        guard case .failure(let trouble) = QuickPromptCall.find(
            id: "Explain changes", in: library, tool: "quick_prompt_delete"
        ) else { Issue.record("expected a refusal"); return }
        #expect(trouble.sentence.contains("quick_prompt_list"))
        #expect(trouble.sentence.contains("'Explain changes' (id one)"))
        #expect(trouble.sentence.contains("'Run make test.' (id two)"))
    }

    @Test("a missing id names the argument and the tool that prints one")
    func aMissingID() {
        for blank in [nil, "", "  "] as [String?] {
            guard case .failure(let trouble) = QuickPromptCall.find(
                id: blank, in: library, tool: "quick_prompt_update"
            ) else { Issue.record("expected a refusal"); return }
            #expect(trouble.sentence.contains("'id'"))
            #expect(trouble.sentence.contains("quick_prompt_update"))
        }
    }

    @Test("an empty library says so, and points at the tool that writes one")
    func anEmptyLibrary() {
        guard case .failure(let trouble) = QuickPromptCall.find(
            id: "one", in: [], tool: "quick_prompt_delete"
        ) else { Issue.record("expected a refusal"); return }
        #expect(trouble.sentence.contains("quick_prompt_create"))
        #expect(trouble.sentence.contains("Retrying will not change that"))
    }

    @Test("a long library is not quoted in full")
    func aLongLibraryIsCut() {
        let many = (0..<40).map { QuickPrompt(id: QuickPromptID("id\($0)"), name: "p\($0)", text: "t") }
        guard case .failure(let trouble) = QuickPromptCall.find(
            id: "nope", in: many, tool: "quick_prompt_update"
        ) else { Issue.record("expected a refusal"); return }
        #expect(trouble.sentence.contains("and \(40 - QuickPromptTrouble.listingLimit) more"))
        #expect(!trouble.sentence.contains("id39"))
    }
}

@Suite("Who may touch a quick prompt")
struct QuickPromptToolRoleTests {
    @Test("a parent may read and write, and only the owner may change or delete")
    func roles() {
        #expect(QuickPromptListTool().roles == [.parent, .owner])
        #expect(QuickPromptCreateTool().roles == [.parent, .owner])
        #expect(QuickPromptUpdateTool().roles == [.owner])
        #expect(QuickPromptDeleteTool().roles == [.owner])
    }

    @Test("a child sees whoami and nothing else, quick prompts included")
    func aChildSeesNothing() {
        #expect(BridgeToolbox.standard.tools(for: .child).map(\.name) == ["whoami"])
    }

    @Test("all four are served without the app, and the owner sees all four")
    func servedByTheStandardToolbox() {
        let owned = Set(BridgeToolbox.standard.tools(for: .owner).map(\.name))
        #expect(owned.isSuperset(of: [
            "quick_prompt_list", "quick_prompt_create", "quick_prompt_update", "quick_prompt_delete",
        ]))
        #expect(
            Set(BridgeToolbox.standard.tools(for: .parent).map(\.name))
                .isDisjoint(with: ["quick_prompt_update", "quick_prompt_delete"])
        )
    }

    @Test("Unified Dev answers for the listing and for none of the other three")
    func selfApproval() {
        #expect(BridgeToolApproval.isSelfApproved(
            toolName: "\(BridgeToolApproval.toolPrefix)quick_prompt_list"
        ))
        for tool in ["quick_prompt_create", "quick_prompt_update", "quick_prompt_delete"] {
            #expect(!BridgeToolApproval.selfApproved.contains(tool))
        }
    }

    @Test("the four take between them an id, a name, a mark and a text, and nothing else")
    func schemas() {
        #expect(QuickPromptListTool().tool.inputSchema == BridgeTool.noArguments)
        #expect(properties(of: QuickPromptCreateTool().tool) == ["name", "symbol", "text"])
        #expect(properties(of: QuickPromptUpdateTool().tool) == ["id", "name", "symbol", "text"])
        #expect(properties(of: QuickPromptDeleteTool().tool) == ["id"])

        #expect(required(of: QuickPromptCreateTool().tool) == [.string("text")])
        #expect(required(of: QuickPromptUpdateTool().tool) == [.string("id")])
        #expect(required(of: QuickPromptDeleteTool().tool) == [.string("id")])
    }

    @Test("the update tool says out loud what a field left out does")
    func theUpdateDescriptionSaysWhatPartialMeans() {
        let description = QuickPromptUpdateTool().tool.description
        #expect(description.contains("keeps the value it already has"))
        #expect(description.contains("no undo"))
    }

    @Test("the delete tool says there is no undo and that a built-in stays deleted")
    func theDeleteDescriptionSaysThereIsNoUndo() {
        let description = QuickPromptDeleteTool().tool.description
        #expect(description.contains("no undo"))
        #expect(description.contains("stays deleted"))
        #expect(description.contains("quick_prompt_create"))
    }

    private func properties(of tool: BridgeTool) -> Set<String> {
        guard case .object(let schema) = tool.inputSchema,
              case .object(let properties)? = schema["properties"]
        else { Issue.record("no schema for \(tool.name)"); return [] }
        return Set(properties.keys)
    }

    private func required(of tool: BridgeTool) -> [JSONValue] {
        guard case .object(let schema) = tool.inputSchema,
              case .array(let required)? = schema["required"]
        else { Issue.record("no required list for \(tool.name)"); return [] }
        return required
    }
}

@Suite("Quick prompt tools, end to end", .tags(.persistence), .scratchDirectory)
struct QuickPromptToolCallTests {
    private func call(
        _ handler: any BridgeToolHandling,
        _ arguments: [String: JSONValue] = [:],
        as role: BridgeRole = .owner,
        store: Store
    ) async -> BridgeToolResult {
        let identity: BridgeIdentity = role == .owner
            ? .owner
            : BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: role)
        return await handler.call(
            MCPRequest(id: .number(1), method: handler.tool.name, params: .object(arguments)),
            as: identity,
            store: store
        )
    }

    private func fields(_ result: BridgeToolResult) -> [String: JSONValue] {
        guard let data = result.text.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .object(let fields) = value
        else { Issue.record("not a JSON object: \(result.text)"); return [:] }
        return fields
    }

    @Test("a created prompt is a row the panel would draw")
    func createsARow() async throws {
        let store = try makeTestStore("quick-prompt-tools")
        let result = await call(
            QuickPromptCreateTool(),
            ["name": .string("Ship it"), "symbol": .string("🚀"), "text": .string("Open a PR.")],
            store: store
        )

        #expect(!result.isError)
        let written = try await store.quickPrompts().first { $0.name == "Ship it" }
        #expect(written?.text == "Open a PR.")
        #expect(written?.symbol == "🚀")
        #expect(fields(result)["id"] == .string(written?.id.rawValue ?? ""))
    }

    @Test("a workspace agent may write one and may read the list")
    func aParentMayWrite() async throws {
        let store = try makeTestStore("quick-prompt-tools")
        let written = await call(
            QuickPromptCreateTool(), ["text": .string("Explain this diff.")],
            as: .parent, store: store
        )
        #expect(!written.isError)

        let listed = await call(QuickPromptListTool(), as: .parent, store: store)
        #expect(!listed.isError)
        #expect(listed.text.contains("Explain this diff."))
    }

    @Test("changing the name alone leaves the text and the mark exactly as they were")
    func updatesNarrowly() async throws {
        let store = try makeTestStore("quick-prompt-tools")
        let original = try await store.insert(
            QuickPrompt(name: "Tests", symbol: "hammer", text: "Run make test.")
        )

        let result = await call(
            QuickPromptUpdateTool(),
            ["id": .string(original.id.rawValue), "name": .string("Run the tests")],
            store: store
        )

        #expect(!result.isError)
        #expect(fields(result)["changed"] == .array([.string("name")]))
        let after = try await store.quickPrompt(id: original.id)
        #expect(after?.name == "Run the tests")
        #expect(after?.text == "Run make test.")
        #expect(after?.symbol == "hammer")
        #expect(after?.sortOrder == original.sortOrder)
    }

    @Test("an update to an id Unified Dev does not have changes nothing and lists what it has")
    func updatesNothingOnAnUnknownID() async throws {
        let store = try makeTestStore("quick-prompt-tools")
        let original = try await store.insert(QuickPrompt(name: "Tests", text: "Run make test."))

        let result = await call(
            QuickPromptUpdateTool(),
            ["id": .string("not-an-id"), "text": .string("Something else.")],
            store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("'Tests' (id \(original.id.rawValue))"))
        #expect(try await store.quickPrompt(id: original.id)?.text == "Run make test.")
    }

    @Test("a delete hands the whole prompt back on its way out")
    func deleteCarriesThePromptBack() async throws {
        let store = try makeTestStore("quick-prompt-tools")
        let original = try await store.insert(
            QuickPrompt(name: "Tests", symbol: "hammer", text: "Run make test.")
        )

        let result = await call(
            QuickPromptDeleteTool(), ["id": .string(original.id.rawValue)], store: store
        )

        #expect(!result.isError)
        #expect(fields(result)["text"] == .string("Run make test."))
        #expect(fields(result)["symbol"] == .string("hammer"))
        #expect(fields(result)["deleted"] == .bool(true))
        #expect(try await store.quickPrompt(id: original.id) == nil)
        #expect(try await store.quickPrompts().count == QuickPromptSeed.all.count)
    }

    @Test("the listing counts what it prints")
    func listsEverything() async throws {
        let store = try makeTestStore("quick-prompt-tools")
        for name in ["first", "second"] {
            try await store.insert(QuickPrompt(name: name, text: name))
        }

        let result = await call(QuickPromptListTool(), store: store)
        guard case .array(let prompts)? = fields(result)["prompts"] else {
            Issue.record("no prompts in \(result.text)"); return
        }
        #expect(prompts.count == 2 + QuickPromptSeed.all.count)
        #expect(fields(result)["count"] == .integer(prompts.count))
    }
}
