import Testing
import Foundation
@testable import Core

private func sessionFixtureLines() throws -> [String] {
    try fixtureLines("session-basic.jsonl")
}

private func makeStoredSession(_ store: Store) async throws -> Session {
    let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r-\(UUID().uuidString)"))
    let workspace = try await store.upsert(Workspace(
        repoID: repo.id, name: "w", branch: "b", path: "/tmp/w", baseBranch: "main"
    ))
    return try await store.upsert(Session(
        workspaceID: workspace.id, title: "New session", model: "opus"
    ))
}

@Suite("Session write isolation", .tags(.persistence), .scratchDirectory)
struct SessionWriteIsolationTests {
    @Test("a title and a model changed mid turn survive the runner's next write")
    func runnerKeepsPreferencesChangedMidTurn() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let initLine = try #require(try sessionFixtureLines().first { $0.contains("\"subtype\":\"init\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: initLine)))

        try await store.updateSessionPreferences(
            id: session.id, title: "Renamed mid turn", model: "sonnet", effort: "low"
        )

        let resultLine = try #require(try sessionFixtureLines().last { $0.contains("\"type\":\"result\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: resultLine)))

        let stored = try #require(try await store.session(id: session.id))
        #expect(stored.title == "Renamed mid turn")
        #expect(stored.model == "sonnet")
        #expect(stored.effort == "low")
        #expect(stored.agentSessionID == "f93932c9-cf0b-40d8-881c-ac75db3f8740")
        #expect(stored.state == .idle)
        #expect(stored.outputTokens == 360)
    }

    @Test("a session closed mid turn stays closed")
    func runnerDoesNotReopenAClosedSession() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let initLine = try #require(try sessionFixtureLines().first { $0.contains("\"subtype\":\"init\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: initLine)))

        try await store.update(sessionID: session.id) { $0.archivedAt = Date() }

        let resultLine = try #require(try sessionFixtureLines().last { $0.contains("\"type\":\"result\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: resultLine)))

        #expect(try await store.session(id: session.id)?.archivedAt != nil)
    }

    @Test("the read mark set while a turn ran is not undone by the runner")
    func runnerKeepsTheReadMark() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let initLine = try #require(try sessionFixtureLines().first { $0.contains("\"subtype\":\"init\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: initLine)))

        try await store.updateLastReadSeq(sessionID: session.id, seq: 42)
        try await store.reorderSessions(ids: [session.id])

        let resultLine = try #require(try sessionFixtureLines().last { $0.contains("\"type\":\"result\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: resultLine)))

        let stored = try #require(try await store.session(id: session.id))
        #expect(stored.lastReadSeq == 42)
        #expect(stored.sortOrder == 0)
    }

    @Test("the runner still writes the agent session id, the state and the counters")
    func runnerStillWritesWhatItOwns() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        for line in try sessionFixtureLines() {
            guard let event = AgentEvent.decode(line: line) else { continue }
            await runner.ingest(event)
        }

        let stored = try #require(try await store.session(id: session.id))
        #expect(stored.agentSessionID == "f93932c9-cf0b-40d8-881c-ac75db3f8740")
        #expect(stored.state == .idle)
        #expect(stored.inputTokens == 6)
        #expect(stored.outputTokens == 360)
        #expect(stored.costUSD > 0)
        #expect(await runner.launch().arguments.suffix(2)
            == ["--resume", "f93932c9-cf0b-40d8-881c-ac75db3f8740"])
    }

    @Test("the runner cannot reinsert a session whose workspace is gone")
    func runnerDoesNotReinsertADeletedSession() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        try await store.deleteSession(id: session.id)

        let resultLine = try #require(try sessionFixtureLines().last { $0.contains("\"type\":\"result\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: resultLine)))

        #expect(try await store.session(id: session.id) == nil)
    }

    @Test("a write leaves alone every column it did not name")
    func writeTouchesOnlyWhatItNames() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)

        try await store.update(sessionID: session.id) {
            $0.agentSessionID = "resume-me"
            $0.state = .running
            $0.inputTokens = 11
        }
        try await store.update(sessionID: session.id) { $0.title = "Renamed" }
        try await store.update(sessionID: session.id) { $0.archivedAt = Date() }

        let stored = try #require(try await store.session(id: session.id))
        #expect(stored.title == "Renamed")
        #expect(stored.archivedAt != nil)
        #expect(stored.agentSessionID == "resume-me")
        #expect(stored.state == .running)
        #expect(stored.inputTokens == 11)
        #expect(stored.workspaceID == session.workspaceID)
    }

    @Test("a targeted write does not recreate a session that is gone")
    func doesNotRecreateADeletedSession() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)
        try await store.deleteSession(id: session.id)

        let result = try await store.update(sessionID: session.id) { $0.title = "back from the dead" }

        #expect(result == nil)
        #expect(try await store.session(id: session.id) == nil)
    }

    @Test("a write cannot change which session it is or which workspace it belongs to")
    func cannotChangeIdentity() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)

        try await store.update(sessionID: session.id) {
            $0.id = SessionID("some-other-id")
            $0.workspaceID = WorkspaceID("some-other-workspace")
            $0.title = "Renamed"
        }

        let stored = try #require(try await store.session(id: session.id))
        #expect(stored.id == session.id)
        #expect(stored.workspaceID == session.workspaceID)
        #expect(stored.title == "Renamed")
    }

    @Test("a whole-value write from a copy read earlier takes the resume id with it")
    func wholeValueWriteLosesTheResumeID() async throws {
        let store = try makeTestStore("session-isolation")
        let session = try await makeStoredSession(store)
        let held = session

        try await store.update(sessionID: session.id) {
            $0.agentSessionID = "f93932c9-cf0b-40d8-881c-ac75db3f8740"
            $0.state = .running
        }
        try await store.upsert(held.with { $0.title = "Renamed" })

        let stored = try #require(try await store.session(id: session.id))
        #expect(stored.title == "Renamed")
        #expect(stored.agentSessionID == nil)
        #expect(stored.state == .idle)

        let next = AgentRunner(workspacePath: "/tmp/w", session: stored, store: store)
        #expect(await next.launch().arguments.contains("--resume") == false)
    }
}
