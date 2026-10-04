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

    @Test("the snapshot description says the three things an agent has to know before it acts")
    func theDescriptionCarriesItsLimits() {
        let said = BrowserPageOutlineTool { _, _ in .told("") }.tool.description

        #expect(said.contains("[e7]"))
        #expect(said.contains("password"))
        #expect(said.contains("untrusted"))
    }
}
