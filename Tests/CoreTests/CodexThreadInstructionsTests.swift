import Foundation
import Testing
@testable import Core

@Suite("What a Codex thread is told when it opens", .scratchDirectory)
struct CodexThreadInstructionsTests {
    private static let attachment = BridgeAttachment(
        shimPath: "/tmp/bridge", socketPath: "/tmp/socket", token: "unused", role: .workspace
    )

    @Test("A workspace chat with the bridge learns it can read the other chats")
    func workspaceChat() throws {
        let text = try #require(CodexThreadInstructions.text(inWorkspace: true, orchestrates: false, hasBridge: true))
        #expect(text.contains("chat_list"))
        #expect(text.contains("chat_read"))
        #expect(text.contains(BridgeRegistration.serverName))
        #expect(!text.contains(OrchestratorRole.instructions))
    }

    @Test("An orchestrator keeps its role and learns the same")
    func orchestrator() throws {
        let text = try #require(CodexThreadInstructions.text(inWorkspace: true, orchestrates: true, hasBridge: true))
        #expect(text.hasPrefix(OrchestratorRole.instructions))
        #expect(text.contains("chat_read to read it"))
    }

    @Test("Without the bridge nothing promises tools that are not there")
    func noBridge() {
        #expect(CodexThreadInstructions.text(inWorkspace: true, orchestrates: false, hasBridge: false) == nil)
        #expect(CodexThreadInstructions.text(inWorkspace: true, orchestrates: true, hasBridge: false)
            == OrchestratorRole.instructions)
    }

    @Test("An Ask conversation keeps its own instructions")
    func askConversation() {
        #expect(CodexThreadInstructions.text(inWorkspace: false, orchestrates: false, hasBridge: true)
            == AskConversation.instructions)
    }

    @Test("The thread is opened with those instructions", arguments: [true, false])
    func threadStartCarriesThem(hasBridge: Bool) async throws {
        let store = try makeTestStore("codex-thread-instructions")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r-\(UUID().uuidString)"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: "/tmp/w", baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, agentKind: .codex))
        let box = ProcessBox()
        let opened = JSONValue.object(["thread": .object(["id": .string("thread")]), "model": .string("m")])
        box.reply(to: "thread/start", with: opened)
        box.reply(to: "turn/start", with: .object([
            "turn": .object(["id": .string("turn"), "status": .string("inProgress"), "items": .array([])]),
        ]))
        let runner = CodexRunner(
            workspacePath: "/tmp/w", session: session, store: store,
            segmentID: try await activeSegmentID(store, session),
            bridge: hasBridge ? Self.attachment : nil,
            makeClient: { CodexClient(configuration: $0, makeProcess: box.factory) }
        )

        try await runner.send("Hello")

        let start = try #require(box.process.sentFrame { $0["method"]?.stringValue == "thread/start" })
        let instructions = start["params"]?["developerInstructions"]?.stringValue
        #expect((instructions?.contains("chat_read") == true) == hasBridge)
        await runner.shutdown()
    }
}
