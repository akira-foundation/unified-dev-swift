import Foundation
import Testing
@testable import Core

@Suite("A Codex rewind needs proof", .scratchDirectory)
struct CodexRewindProofTests {
    private static let thread = "01a02144-3b7e-7233-97f2-73ebd5105085"
    private static let otherThread = "01a02144-3b7e-7233-97f2-000000000099"
    private static let turn = "01a02144-3bab-7fe3-a92c-6eec594d84fd"
    private static let goneMessage = "thread not loaded: 01a02144-3b7e-7233-97f2-73ebd5105085"

    private func box(turns: [String] = [turn]) -> ProcessBox {
        let box = ProcessBox()
        box.reply(to: "thread/read", with: .object([
            "thread": .object(["id": .string(Self.thread), "historyMode": .string("paginated")]),
        ]))
        box.reply(to: "thread/turns/list", with: .object([
            "data": .array(turns.map { .object(["id": .string($0)]) }), "nextCursor": .null,
        ]))
        box.reply(to: "thread/resume", with: .object(["thread": .object(["id": .string(Self.thread)])]))
        box.reply(to: "thread/start", with: .object(["thread": .object(["id": .string(Self.otherThread)])]))
        box.reply(to: "thread/revert", with: .object([:]))
        return box
    }

    private func chat(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r-\(UUID().uuidString)"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: "/tmp/w", baseBranch: "main"
        ))
        return try await store.upsert(Session(
            workspaceID: workspace.id, agentSessionID: Self.thread, agentKind: .codex
        ))
    }

    private func runner(_ store: Store, _ session: Session, _ box: ProcessBox) async throws -> CodexRunner {
        CodexRunner(
            workspacePath: "/tmp/w", session: session, store: store,
            segmentID: try await activeSegmentID(store, session),
            makeClient: { CodexClient(configuration: $0, makeProcess: box.factory) }
        )
    }

    @Test("asking about a turn opens no thread and writes nothing", arguments: [true, false])
    func askingIsARead(retained: Bool) async throws {
        let store = try makeTestStore("rewind-proof-read")
        let session = try await chat(store)
        let box = box(turns: retained ? [Self.turn] : ["another"])
        let runner = try await runner(store, session, box)
        let before = try #require(try await store.session(id: session.id))

        let presence = try await runner.turnPresence(Self.turn)

        #expect(presence == (retained ? .retained(threadID: Self.thread) : .absent(threadID: Self.thread)))
        #expect(!box.process.sentMethods.contains("thread/resume"))
        #expect(!box.process.sentMethods.contains("thread/start"))
        let after = try #require(try await store.session(id: session.id))
        #expect(after.agentSessionID == Self.thread)
        #expect(after.updatedAt == before.updatedAt)
        await runner.shutdown()
    }

    @Test("a thread the server has lost is reported as lost, and nothing replaces it")
    func lostThread() async throws {
        let store = try makeTestStore("rewind-proof-lost")
        let session = try await chat(store)
        let box = box()
        box.fail("thread/read", code: -32600, message: Self.goneMessage)
        let runner = try await runner(store, session, box)

        #expect(try await runner.turnPresence(Self.turn) == .threadMissing)
        #expect(!box.process.sentMethods.contains("thread/start"))
        #expect(try await store.session(id: session.id)?.agentSessionID == Self.thread)
        await runner.shutdown()
    }

    @Test("a server that cannot answer is no evidence about the turn")
    func unanswered() async throws {
        let store = try makeTestStore("rewind-proof-unanswered")
        let session = try await chat(store)
        let box = box()
        box.fail("thread/read", code: -32603, message: "internal error")
        let runner = try await runner(store, session, box)

        await #expect(throws: CodexRPCError.self) { try await runner.turnPresence(Self.turn) }
        await runner.shutdown()
    }

    @Test("only the sentences measured from the server mean the thread is gone", arguments: [
        (-32600, "thread not loaded: abc", true),
        (-32600, "no rollout found for thread id abc", true),
        (-32600, "invalid paginated history lineage for abc: missing source rollout", true),
        (-32600, "turn not found: abc", false),
        (-32603, "thread not loaded: abc", false),
    ])
    func goneSentences(code: Int, message: String, gone: Bool) {
        #expect(CodexClient.saysThreadIsGone(CodexRPCError(code: code, message: message)) == gone)
    }

    @Test("a chat with no stored thread has nothing to ask about")
    func noStoredThread() async throws {
        let store = try makeTestStore("rewind-proof-none")
        var session = try await chat(store)
        session.agentSessionID = nil
        let box = box()
        let runner = try await runner(store, session, box)

        #expect(try await runner.turnPresence(Self.turn) == .threadMissing)
        await runner.shutdown()
    }

    @Test("a rewind whose resume fails starts no thread and keeps the stored one")
    func failedResume() async throws {
        let store = try makeTestStore("rewind-proof-resume")
        let session = try await chat(store)
        let box = box()
        box.fail("thread/resume", code: -32600, message: "no rollout found for thread id \(Self.thread)")
        let runner = try await runner(store, session, box)

        await #expect(throws: CodexRPCError.self) { try await runner.rewind(beforeTurnID: Self.turn) }

        #expect(!box.process.sentMethods.contains("thread/start"))
        #expect(!box.process.sentMethods.contains("thread/revert"))
        #expect(try await store.session(id: session.id)?.agentSessionID == Self.thread)
        await runner.shutdown()
    }

    @Test("a rewind answered with another thread reverts nothing and writes nothing")
    func differentThread() async throws {
        let store = try makeTestStore("rewind-proof-other")
        let session = try await chat(store)
        let box = box()
        box.reply(to: "thread/resume", with: .object(["thread": .object(["id": .string(Self.otherThread)])]))
        let runner = try await runner(store, session, box)

        await #expect(throws: ConversationRewindError.invalidHistory) {
            try await runner.rewind(beforeTurnID: Self.turn)
        }

        #expect(!box.process.sentMethods.contains("thread/revert"))
        #expect(try await store.session(id: session.id)?.agentSessionID == Self.thread)
        await runner.shutdown()
    }

    @Test("a rewind resumes the stored thread and reverts it")
    func resumesAndReverts() async throws {
        let store = try makeTestStore("rewind-proof-happy")
        let session = try await chat(store)
        let box = box()
        let runner = try await runner(store, session, box)

        try await runner.rewind(beforeTurnID: Self.turn)

        #expect(box.process.sentMethods.contains("thread/resume"))
        let revert = try #require(box.process.sentFrame { $0["method"]?.stringValue == "thread/revert" })
        #expect(revert["params"]?["threadId"]?.stringValue == Self.thread)
        #expect(revert["params"]?["beforeTurnId"]?.stringValue == Self.turn)
        #expect(!box.process.sentMethods.contains("thread/start"))
        await runner.shutdown()
    }
}

@Suite("Resolving an interrupted rewind", .scratchDirectory)
struct InterruptedRewindDecisionTests {
    private static let recorded = "thread-held-the-turn"

    private func journal(recording thread: String? = recorded) -> CheckpointRewind {
        let session = SessionID.new()
        return CheckpointRewind(
            checkpoint: TurnCheckpoint(sessionID: session, startSeq: 1, before: GitSnapshot(sessionID: session)),
            recovery: nil, restoringFiles: false, providerThreadID: thread
        )
    }

    @Test("the thread that held the turn no longer has it, so the rewind happened")
    func provenRevert() {
        #expect(journal().recoveryDecision(given: .absent(threadID: Self.recorded)) == .completeRewind)
    }

    @Test("a turn still present means the rewind did not happen")
    func retained() {
        #expect(journal().recoveryDecision(given: .retained(threadID: Self.recorded)) == .undoRewind)
    }

    @Test("a different thread without the turn proves nothing")
    func otherThread() {
        #expect(journal().recoveryDecision(given: .absent(threadID: "a-new-thread")) == .undoUnproven)
    }

    @Test("a lost thread proves nothing")
    func lostThread() {
        #expect(journal().recoveryDecision(given: .threadMissing) == .undoUnproven)
    }

    @Test("a journal that recorded no thread proves nothing")
    func journalFromBeforeTheRecord() {
        #expect(journal(recording: nil).recoveryDecision(given: .absent(threadID: Self.recorded)) == .undoUnproven)
    }

    @Test("a journal written by an older build still decodes")
    func olderJournalDecodes() throws {
        let data = try JSONEncoder().encode(journal())
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "providerThreadID")
        let older = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(CheckpointRewind.self, from: older).providerThreadID == nil)
    }

    @Test("preparing a rewind records the thread that held the turn")
    func preparingRecordsTheThread() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("rewind-records-thread")
        let service = TurnCheckpointStore(store: store)
        let session = SessionID.new()
        let checkpoint = try await service.begin(sessionID: session, cwd: repo.path, startSeq: 1)

        _ = try await service.prepareRewind(
            checkpoint: checkpoint, cwd: repo.path, restoringFiles: false, providerThreadID: Self.recorded
        )

        #expect(try await store.checkpointRewind(sessionID: session)?.providerThreadID == Self.recorded)
    }
}
