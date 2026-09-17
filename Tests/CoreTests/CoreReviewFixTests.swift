import Testing
import Foundation
@testable import Core

private func scriptedBox() -> ProcessBox {
    let box = ProcessBox()
    let threadStartReply = JSONValue.object([
        "thread": .object(["id": .string("01a02144-3b7e-7233-97f2-73ebd5105085")]),
        "model": .string("gpt-5.6-sol"),
    ])
    box.reply(to: "thread/start", with: threadStartReply)
    box.reply(to: "thread/resume", with: threadStartReply)
    box.reply(to: "turn/start", with: .object([
        "turn": .object([
            "id": .string("01a02144-3bab-7fe3-a92c-6eec594d84fd"),
            "status": .string("inProgress"),
            "items": .array([]),
        ]),
    ]))
    return box
}

@Suite("CodexRunner persistence failures", .tags(.persistence), .scratchDirectory, .timeLimit(.minutes(1)))
struct CodexRunnerPersistenceFailureTests {
    @Test("surfaces a failed write instead of pretending the row landed")
    func surfacesFailedAppend() async throws {
        let store = try makeTestStore("codex-persistence")
        let session = try await makeCodexSession(store)
        let refusing = try SQLiteDatabase(path: store.path)
        try refusing.execute("""
            CREATE TRIGGER refuse_messages BEFORE INSERT ON messages
            BEGIN SELECT RAISE(ABORT, 'the transcript table is bolted shut'); END;
            """)
        defer { try? refusing.execute("DROP TRIGGER refuse_messages") }
        let box = scriptedBox()
        let runner = CodexRunner(
            workspacePath: "/tmp/w",
            session: session,
            store: store,
            makeClient: { configuration in
                CodexClient(configuration: configuration, makeProcess: box.factory)
            }
        )

        let events = runner.events
        try await runner.send("hello")

        let first = await withTaskGroup(of: AgentEvent?.self) { group in
            group.addTask {
                for await event in events { return event }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return nil
            }
            // swiftlint:disable:next redundant_nil_coalescing
            let winner = await group.next() ?? nil
            group.cancelAll()
            return winner
        }
        guard case .error(let failure) = first else {
            Issue.record("the failed write should reach the stream as an error, got \(String(describing: first))")
            return
        }
        #expect(failure.message == WorkspaceTrouble.transcriptUnwritable(
            complaint: "the transcript table is bolted shut."
        ).sentence)
        #expect(JSONValue.parse(failure.raw)?["subtype"]?.stringValue == "storage")

        #expect(await runner.lastPersistenceFailure != nil)
        #expect(await runner.persistenceFailureCount == 1)
        #expect(try await store.messageCount(sessionID: session.id) == 0)
    }

    @Test("a write for a workspace that has just been deleted is dropped without a word")
    func deletedWorkspaceIsSilent() async throws {
        let store = try makeTestStore("codex-persistence")
        var session = try await makeCodexSession(store)
        _ = session.apply(.turnStarted)
        session = try await store.upsert(session)
        let box = scriptedBox()
        let runner = CodexRunner(
            workspacePath: "/tmp/w",
            session: session,
            store: store,
            makeClient: { configuration in
                CodexClient(configuration: configuration, makeProcess: box.factory)
            }
        )

        let events = runner.events
        try await store.deleteWorkspace(id: try #require(session.workspaceID))
        try? await runner.send("hello")

        let first = await withTaskGroup(of: AgentEvent?.self) { group in
            group.addTask {
                for await event in events { return event }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return nil
            }
            // swiftlint:disable:next redundant_nil_coalescing
            let winner = await group.next() ?? nil
            group.cancelAll()
            return winner
        }
        if case .error = first {
            Issue.record("a workspace the owner deleted must not be reported as a database fault")
        }
        #expect(await runner.persistenceFailureCount == 0)
        #expect(await runner.lastPersistenceFailure == nil)
        #expect(await runner.transcriptWasRemoved)
    }
}

private func makeCodexSession(_ store: Store) async throws -> Session {
    let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r-\(UUID().uuidString)"))
    let workspace = try await store.upsert(Workspace(
        repoID: repo.id, name: "w", branch: "b", path: "/tmp/w", baseBranch: "main"
    ))
    return try await store.upsert(Session(workspaceID: workspace.id, agentKind: .codex))
}

@Suite("Git.runRaw cancellation", .scratchDirectory)
struct GitRunRawCancellationTests {
    @Test("a cancelled caller is refused before git is spawned")
    func cancelledCallerThrows() async {
        let task = Task { () -> GitOutput in
            while !Task.isCancelled { await Task.yield() }
            return try await Git.runRaw(["status", "--porcelain", "-z"], in: "/tmp")
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
