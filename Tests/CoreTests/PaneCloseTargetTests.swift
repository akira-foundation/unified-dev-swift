import Testing
@testable import Core

@Suite("What pane_close is asked to close", .scratchDirectory)
struct PaneCloseTargetTests {
    @Test("no kind, or a blank one, closes the focused pane")
    func focused() {
        #expect(PaneCloseTarget.parse(nil) == .success(.focused))
        #expect(PaneCloseTarget.parse("  ") == .success(.focused))
    }

    @Test("every kind pane_open opens is closed by name", arguments: PaneKind.allCases)
    func paneKinds(_ kind: PaneKind) {
        #expect(PaneCloseTarget.parse(" \(kind.rawValue) ") == .success(.pane(kind)))
    }

    @Test("'canvas' closes the workspace's canvas")
    func canvas() {
        #expect(PaneCloseTarget.parse("canvas") == .success(.canvas))
    }

    @Test("an unknown kind is refused with every word that would have worked")
    func unknown() {
        guard case .failure(let refusal) = PaneCloseTarget.parse("review") else {
            Issue.record("the review was accepted")
            return
        }
        for word in PaneCloseTarget.words {
            #expect(refusal.sentence.contains("'\(word)'"))
        }
    }

    @Test("the tool's schema offers exactly the words it parses")
    func schema() {
        let tool = PaneCloseTool { _, _ in .opened("") }.tool
        guard case .object(let schema) = tool.inputSchema,
              case .object(let properties)? = schema["properties"],
              case .object(let kind)? = properties["kind"],
              case .array(let words)? = kind["enum"]
        else {
            Issue.record("no kind in the schema")
            return
        }
        #expect(words == PaneCloseTarget.words.map { .string($0) })
        #expect(tool.description.contains("'canvas'"))
    }

    @Test("the tool hands the parsed target to the app")
    func call() async throws {
        let store = try makeTestStore("pane-close-target")
        let recorder = Recorder()
        let tool = PaneCloseTool { target, _ in
            await recorder.record(target)
            return .opened("closed")
        }
        let identity = BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
        let request = MCPRequest(id: .integer(1), method: "pane_close", params: .object(["kind": .string("canvas")]))

        let result = await tool.call(request, as: identity, store: store)

        #expect(!result.isError)
        #expect(await recorder.targets == [.canvas])
    }

    private actor Recorder {
        var targets: [PaneCloseTarget] = []
        func record(_ target: PaneCloseTarget) { targets.append(target) }
    }
}
