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

    @Test("a press can go to the page or to one element")
    func pressGoesWhereItWasAimed() async throws {
        let seen = Box<BrowserPaneCommand?>(nil)
        let tool = BrowserPressTool { command, _ in
            seen.value = command
            return .told("Sent enter to the page.")
        }

        _ = await tool.call(
            request(["key": .string("enter")]), as: identity(), store: try makeTestStore("press")
        )
        #expect(seen.value == .press(nil, .enter, nil))

        _ = await tool.call(
            request(["key": .string("tab"), "element": .string("e4")]),
            as: identity(), store: try makeTestStore("press-element")
        )
        #expect(seen.value == .press(nil, .tab, BrowserAgentReference(index: 4)))
    }

    @Test("a press of a key that is not offered is refused before the page is touched")
    func pressRefusesAKeyItDoesNotSend() async throws {
        let tool = BrowserPressTool { _, _ in .told("should not be reached") }

        let result = await tool.call(
            request(["key": .string("cmd+s")]), as: identity(), store: try makeTestStore("press-bad")
        )

        #expect(result.isError)
        #expect(result.text.contains("'enter'"))
    }

    @Test("a wait says what it is waiting for and for how long")
    func waitCarriesItsCondition() async throws {
        let seen = Box<BrowserPaneCommand?>(nil)
        let tool = BrowserWaitTool { command, _ in
            seen.value = command
            return .told("\"Saved\" appeared after 1.2 seconds.")
        }

        _ = await tool.call(
            request(["text": .string("Saved"), "seconds": .integer(5)]),
            as: identity(), store: try makeTestStore("wait")
        )

        #expect(seen.value == .wait(nil, .text("Saved"), seconds: 5))
    }

    @Test("a wait with nothing to look for waits for the load, with the fallback ceiling")
    func aBareWaitWaitsForTheLoad() async throws {
        let seen = Box<BrowserPaneCommand?>(nil)
        let tool = BrowserWaitTool { command, _ in
            seen.value = command
            return .told("The page finished loading after 0.2 seconds.")
        }

        _ = await tool.call(request(), as: identity(), store: try makeTestStore("wait-load"))

        #expect(seen.value == .wait(nil, .load, seconds: BrowserWaitSeconds.fallback))
    }

    @Test("a wait longer than the ceiling is refused, with the ceiling named")
    func waitIsBounded() async throws {
        let tool = BrowserWaitTool { _, _ in .told("should not be reached") }

        let result = await tool.call(
            request(["seconds": .integer(600)]), as: identity(), store: try makeTestStore("wait-long")
        )

        #expect(result.isError)
        #expect(result.text.contains("\(BrowserWaitSeconds.maximum)"))
    }

    @Test("a wait for two things at once is refused rather than picking one")
    func waitRefusesTwoConditions() async throws {
        let tool = BrowserWaitTool { _, _ in .told("should not be reached") }

        let result = await tool.call(
            request(["text": .string("Saved"), "gone": .string("Spinner")]),
            as: identity(), store: try makeTestStore("wait-both")
        )

        #expect(result.isError)
        #expect(result.text.contains("one thing at a time"))
    }

    @Test("a wait for a page that never settles answers rather than hanging")
    func waitAnswersOnTimeout() async throws {
        let tool = BrowserWaitTool { _, _ in .told("The page did not settle in 2 seconds.") }

        let result = await tool.call(
            request(["seconds": .integer(2)]), as: identity(), store: try makeTestStore("wait-timeout")
        )

        #expect(result.isError == false)
        #expect(result.text.contains("did not settle"))
    }

    @Test("the snapshot description says the three things an agent has to know before it acts")
    func theDescriptionCarriesItsLimits() {
        let said = BrowserPageOutlineTool { _, _ in .told("") }.tool.description

        #expect(said.contains("[e7]"))
        #expect(said.contains("password"))
        #expect(said.contains("untrusted"))
    }
}
