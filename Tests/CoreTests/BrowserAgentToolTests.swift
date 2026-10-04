import Foundation
import Testing
@testable import Core

@Suite("Acting in a browser pane", .scratchDirectory, .tags(.security))
struct BrowserAgentToolTests {
    private func identity() -> BridgeIdentity {
        BridgeIdentity(sessionID: SessionID.new(), workspaceID: WorkspaceID.new(), role: .workspace)
    }

    private func request(_ arguments: [String: JSONValue] = [:]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: "tools/call", params: .object(arguments))
    }

    @Test("a snapshot asks the pane for an outline and hands back what it answered")
    func snapshotAsksForAnOutline() async throws {
        let seen = Box<BrowserPaneCommand?>(nil)
        let tool = BrowserPageOutlineTool { command, _ in
            seen.value = command
            return .told("- button \"Delete\" [e1]")
        }

        let result = await tool.call(request(), as: identity(), store: try makeTestStore("outline"))

        #expect(seen.value == .outline(nil))
        #expect(result.text.contains("[e1]"))
    }

    @Test("a snapshot of a numbered browser carries the number")
    func snapshotCarriesTheNumber() async throws {
        let seen = Box<BrowserPaneCommand?>(nil)
        let tool = BrowserPageOutlineTool { command, _ in
            seen.value = command
            return .told("")
        }

        _ = await tool.call(
            request(["browser": .integer(2)]), as: identity(), store: try makeTestStore("outline-2")
        )

        #expect(seen.value == .outline(2))
    }

    @Test("the owner's client cannot act in anybody's browser")
    func theOwnerIsOutOfScope() async throws {
        let tool = BrowserPageOutlineTool { _, _ in .told("") }

        #expect(tool.roles == [.workspace])
        let result = await tool.call(request(), as: .owner, store: try makeTestStore("outline-owner"))
        #expect(result.isError)
    }

    @Test("none of the five acting tools is self approved")
    func noneIsSelfApproved() {
        for name in [
            BrowserPaneToolName.snapshot, BrowserPaneToolName.click, BrowserPaneToolName.fill,
            BrowserPaneToolName.press, BrowserPaneToolName.wait,
        ] {
            #expect(!BridgeToolApproval.selfApproved.contains(name))
        }
    }

    @Test("a click names the element it was pointed at")
    func clickCarriesItsReference() async throws {
        let seen = Box<BrowserPaneCommand?>(nil)
        let tool = BrowserClickTool { command, _ in
            seen.value = command
            return .told("Pressed e7. The page labels it \"Delete\".")
        }

        let result = await tool.call(
            request(["element": .string("e7")]), as: identity(), store: try makeTestStore("click")
        )

        #expect(seen.value == .click(nil, BrowserAgentReference(index: 7)))
        #expect(result.text.contains("Delete"))
    }

    @Test("a click with no element, or with something that is not one, is refused by name", arguments: [
        JSONValue?.none, .some(.string("")), .some(.string("#submit")),
        .some(.string("the delete button")), .some(.integer(7)),
    ])
    func clickRefusesAnythingButAReference(element: JSONValue?) async throws {
        let tool = BrowserClickTool { _, _ in .told("should not be reached") }
        var arguments: [String: JSONValue] = [:]
        if let element { arguments["element"] = element }

        let result = await tool.call(
            request(arguments), as: identity(), store: try makeTestStore("click-refusal")
        )

        #expect(result.isError)
        #expect(result.text.contains("browser_snapshot"))
    }

    @Test("a fill carries the text as text, and the tool never puts it in a sentence it builds")
    func fillCarriesItsText() async throws {
        let seen = Box<BrowserPaneCommand?>(nil)
        let tool = BrowserFillTool { command, _ in
            seen.value = command
            return .told("Filled e3 with 15 characters.")
        }

        _ = await tool.call(
            request(["element": .string("e3"), "text": .string("kid@example.com")]),
            as: identity(), store: try makeTestStore("fill")
        )

        #expect(seen.value == .fill(nil, BrowserAgentReference(index: 3), "kid@example.com"))
    }

    @Test("a fill with no text is refused, because clearing a field is not what it is for")
    func fillNeedsText() async throws {
        let tool = BrowserFillTool { _, _ in .told("should not be reached") }

        let result = await tool.call(
            request(["element": .string("e3")]), as: identity(), store: try makeTestStore("fill-empty")
        )

        #expect(result.isError)
        #expect(result.text.contains("'text'"))
    }

    @Test("a fill says out loud that a password comes back only as a length")
    func fillSaysWhatAPasswordCostsToRead() {
        let said = BrowserFillTool { _, _ in .told("") }.tool.description

        #expect(said.contains("password"))
        #expect(said.contains("never reads a password field back"))
    }

    @Test("the snapshot description says the three things an agent has to know before it acts")
    func theDescriptionCarriesItsLimits() {
        let said = BrowserPageOutlineTool { _, _ in .told("") }.tool.description

        #expect(said.contains("[e7]"))
        #expect(said.contains("password"))
        #expect(said.contains("untrusted"))
    }
}
