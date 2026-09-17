import Foundation
import Testing
@testable import Core

@Suite("Transcript search")
struct TranscriptSearchTests {
    @Test("a word becomes a quoted prefix term while it is still being typed")
    func prefixesTheWordInProgress() {
        #expect(TranscriptSearch.matchExpression(for: "wal") == "\"wal\"*")
    }

    @Test("a finished word is not prefixed")
    func doesNotPrefixAfterASpace() {
        #expect(TranscriptSearch.matchExpression(for: "wal ") == "\"wal\"")
    }

    @Test("several words are all required")
    func joinsWordsWithAnd() {
        #expect(TranscriptSearch.matchExpression(for: "wal checkpoint") == "\"wal\" AND \"checkpoint\"*")
    }

    @Test("query syntax the user did not mean is quoted away")
    func quotesFTSSyntax() {
        let expression = TranscriptSearch.matchExpression(for: "Store.swift:1881 - ")
        #expect(expression == "\"Store.swift:1881\"")
    }

    @Test("a double quote inside a term is escaped rather than closing the term")
    func escapesQuotes() {
        #expect(TranscriptSearch.matchExpression(for: "say \"\"hi ") == "\"say\" AND \"hi\"")
    }

    @Test("a quoted phrase stays one phrase and is not prefixed")
    func keepsPhrases() {
        #expect(TranscriptSearch.matchExpression(for: "\"write ahead log\"") == "\"write ahead log\"")
    }

    @Test("nothing worth running comes back as nothing to run")
    func refusesEmptyQueries() {
        #expect(TranscriptSearch.matchExpression(for: "") == nil)
        #expect(TranscriptSearch.matchExpression(for: "  ") == nil)
        #expect(TranscriptSearch.matchExpression(for: "a") == nil)
        #expect(TranscriptSearch.matchExpression(for: "-- ") == nil)
    }

    @Test("marks become segments the view can draw without touching the string again")
    func readsMarkedSnippets() {
        let marked = "…the \u{02}WAL\u{03} was truncated…"
        let snippet = TranscriptSearch.snippet(from: marked)

        #expect(snippet.text == "…the WAL was truncated…")
        #expect(snippet.segments.map(\.isMatch) == [false, true, false])
        #expect(snippet.segments[1].text == "WAL")
    }

    @Test("adjacent matched terms read as one highlight")
    func mergesAdjacentSegments() {
        let snippet = TranscriptSearch.snippet(from: "a \u{02}wal\u{03}\u{02} file\u{03} b")
        #expect(snippet.segments.map(\.text) == ["a ", "wal file", " b"])
    }

    @Test("a snippet with no match in it is one plain segment")
    func handlesUnmarkedText() {
        let snippet = TranscriptSearch.snippet(from: "nothing marked")
        #expect(snippet.segments == [TranscriptSnippet.Segment(text: "nothing marked", isMatch: false)])
    }

    private func payload(_ json: String) -> Data { Data(json.utf8) }

    @Test("prose is indexed and the machinery around it is not")
    func indexesProseWithoutIdentifiers() throws {
        let body = try #require(TranscriptSearchText.indexable(
            kind: .assistantText,
            payload: payload("""
            {"type":"assistant","uuid":"9f1c8e2a-4b7d","session_id":"abc-123",
             "message":{"role":"assistant","model":"claude-opus-4",
             "content":[{"type":"text","text":"The WAL was never checkpointed."}]}}
            """)
        ))

        #expect(body.contains("The WAL was never checkpointed."))
        #expect(!body.contains("9f1c8e2a"))
        #expect(!body.contains("abc-123"))
        #expect(!body.contains("claude-opus-4"))
    }

    @Test("a tool call carries its name and its arguments into the index")
    func indexesToolCalls() throws {
        let body = try #require(TranscriptSearchText.indexable(
            kind: .toolUse,
            payload: payload("""
            {"name":"Bash","input":{"command":"sqlite3 unifieddev.sqlite 'PRAGMA wal_checkpoint'",
             "description":"Checkpoint the write ahead log"}}
            """)
        ))

        #expect(body.contains("Bash"))
        #expect(body.contains("wal_checkpoint"))
        #expect(body.contains("Checkpoint the write ahead log"))
    }

    @Test("the accounting a turn carries beside its words stays out of the index")
    func skipsUsageAndStamps() throws {
        let body = try #require(TranscriptSearchText.indexable(
            kind: .assistantText,
            payload: payload("""
            {"type":"assistant","uuid":"a1","request_id":"req_1","timestamp":"2026-08-23T10:22:27.000Z",
             "message":{"role":"assistant","model":"claude-sonnet-5",
             "content":[{"type":"text","text":"Hello. We are looking at the QA worktree."}],
             "usage":{"input_tokens":2,"output_tokens":3,"service_tier":"standard",
             "inference_geo":"not_available"},
             "context_management":{"applied_edits":["cleared the oldest turn"]}},
             "modelUsage":{"claude-sonnet-5":{"provider":"firstParty","canonicalModel":"claude-sonnet-5"}},
             "stop_reason":"end_turn","fast_mode_state":"off"}
            """)
        ))

        #expect(body == "Hello. We are looking at the QA worktree.")
    }

    @Test("the reasoning effort is a setting rather than a sentence")
    func skipsReasoningEffort() throws {
        let body = try #require(TranscriptSearchText.indexable(
            kind: .user,
            payload: payload("""
            {"msg":{"text":"Move the checkpoint into the copy."},
             "reasoningEffort":"medium","effort":"high","created_at":"2026-08-23T10:22:27Z"}
            """)
        ))

        #expect(body == "Move the checkpoint into the copy.")
    }

    @Test("a row of counters and costs is not indexed at all")
    func skipsResultRows() {
        #expect(TranscriptSearchText.indexable(
            kind: .result,
            payload: payload("{\"subtype\":\"success\",\"total_cost_usd\":0.42}")
        ) == nil)
        #expect(TranscriptSearchText.indexable(kind: .notice, payload: payload("{\"a\":\"b\"}")) == nil)
    }

    @Test("the same sentence appearing twice in one line is indexed once")
    func dedupesRepeatedText() throws {
        let body = try #require(TranscriptSearchText.indexable(
            kind: .assistantText,
            payload: payload("{\"text\":\"one sentence\",\"content\":[{\"text\":\"one sentence\"}]}")
        ))
        #expect(body == "one sentence")
    }

    @Test("a payload that is not JSON is still words")
    func handlesPlainPayloads() {
        #expect(TranscriptSearchText.indexable(
            kind: .user, payload: payload("just some text")
        ) == "just some text")
    }

    @Test("a very long tool result is cut rather than indexed whole")
    func capsLongRows() throws {
        let long = String(repeating: "checkpoint ", count: 4_000)
        let body = try #require(TranscriptSearchText.indexable(
            kind: .toolResult, payload: payload("{\"content\":\"\(long)\"}")
        ))
        #expect(body.count <= TranscriptSearchText.limit)
    }

    private func match(_ workspace: String, seq: Int, score: Double) -> TranscriptMatch {
        TranscriptMatch(
            messageID: Int64(seq),
            workspaceID: WorkspaceID(workspace),
            sessionID: SessionID("s-\(workspace)"),
            sessionTitle: "Session",
            seq: seq,
            kind: .assistantText,
            createdAt: Date(timeIntervalSince1970: 0),
            snippet: TranscriptSnippet(segments: []),
            score: score
        )
    }

    @Test("a workspace with many matches is one row that says how many")
    func foldsAWorkspaceIntoOneRow() {
        let matches = (0..<40).map { match("noisy", seq: $0, score: -1) } + [match("quiet", seq: 99, score: -0.5)]
        let grouped = TranscriptSearch.group(matches)

        #expect(grouped.count == 2)
        #expect(grouped[0].workspaceID == WorkspaceID("noisy"))
        #expect(grouped[0].matches.count == TranscriptSearch.matchesPerWorkspace)
        #expect(grouped[0].total == 40)
        #expect(grouped[1].workspaceID == WorkspaceID("quiet"))
    }

    @Test("the count comes from the whole index rather than from what was fetched")
    func prefersTheCountedTotal() {
        let grouped = TranscriptSearch.group(
            [match("w", seq: 1, score: -2)],
            totals: [WorkspaceID("w"): 91]
        )
        #expect(grouped.first?.total == 91)
    }

    @Test("workspaces come back in the order of their best match")
    func keepsRankOrder() {
        let grouped = TranscriptSearch.group([
            match("b", seq: 1, score: -3),
            match("a", seq: 2, score: -2),
            match("b", seq: 3, score: -1),
        ])
        #expect(grouped.map(\.workspaceID) == [WorkspaceID("b"), WorkspaceID("a")])
    }
}

@Suite("Transcript index", .tags(.persistence), .scratchDirectory)
struct TranscriptIndexTests {
    private func makeSession(_ store: Store, workspace name: String = "w") async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r-\(UUID().uuidString)"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: "b", path: "/tmp/\(name)", baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id, title: "Session", model: "opus"))
    }

    private func say(_ store: Store, _ session: Session, _ text: String) async throws {
        try await store.appendNext(
            sessionID: session.id,
            kind: .assistantText,
            payload: Data("{\"text\":\"\(text)\"}".utf8)
        )
    }

    @Test("a message is searchable as soon as it is written")
    func indexesOnInsert() async throws {
        let store = try makeTestStore("transcript-index")
        let session = try await makeSession(store)
        try await say(store, session, "the WAL was never checkpointed")

        let results = try await store.searchTranscripts("checkpoint")
        #expect(results.count == 1)
        #expect(results.first?.matches.first?.sessionID == session.id)
        #expect(results.first?.matches.first?.snippet.segments.contains { $0.isMatch } == true)
    }

    @Test("a search finds a word in another of its forms")
    func stemsTheQueryAndTheText() async throws {
        let store = try makeTestStore("transcript-stem")
        let session = try await makeSession(store)
        try await say(store, session, "I worked out the checkpointing")

        #expect(try await store.searchTranscripts("working ").count == 1)
    }

    @Test("a result carries the session and the position of the row")
    func pointsAtTheRow() async throws {
        let store = try makeTestStore("transcript-target")
        let session = try await makeSession(store)
        try await say(store, session, "nothing to see")
        try await say(store, session, "the vacuum ran")

        let match = try #require(try await store.searchTranscripts("vacuum ").first?.matches.first)
        #expect(match.seq == 1)
        #expect(match.sessionID == session.id)
    }

    @Test("archiving a workspace takes its transcript out of the index with it")
    func followsTheCascade() async throws {
        let store = try makeTestStore("transcript-cascade")
        let session = try await makeSession(store)
        try await say(store, session, "an unrepeatable word: zarquon")
        #expect(try await store.searchTranscripts("zarquon").count == 1)

        try await store.deleteWorkspace(id: try #require(session.workspaceID))
        #expect(try await store.searchTranscripts("zarquon").isEmpty)
    }

    @Test("a database written before the index existed is backfilled, newest first")
    func backfillsInBatches() async throws {
        let path = TestScratch.unique("transcript-backfill") + ".sqlite"
        let store = try Store(path: path)
        let session = try await makeSession(store)
        for index in 0..<10 {
            try await say(store, session, "message number \(index) about pelicans")
        }

        try await store.forgetTranscriptIndexForTesting()
        #expect(try await store.searchTranscripts("pelicans").isEmpty)
        #expect(try await store.isTranscriptIndexIncomplete())

        let first = try await store.indexOlderTranscripts(batch: 4)
        #expect(first.scanned == 4)
        #expect(!first.isFinished)
        #expect(try await store.searchTranscripts("pelicans").first?.total == 4)

        while try await !store.indexOlderTranscripts(batch: 4).isFinished {}
        #expect(try await store.searchTranscripts("pelicans").first?.total == 10)
        #expect(try await !store.isTranscriptIndexIncomplete())
    }

    @Test("re-running a batch that already ran indexes each row once")
    func isSafeToRepeat() async throws {
        let store = try makeTestStore("transcript-repeat")
        let session = try await makeSession(store)
        try await say(store, session, "one about pelicans")
        try await store.forgetTranscriptIndexForTesting()

        try await store.indexOlderTranscripts(batch: 1)
        try await store.rewindTranscriptBackfillForTesting()
        try await store.indexOlderTranscripts(batch: 1)

        #expect(try await store.searchTranscripts("pelicans").first?.total == 1)
    }

    @Test("a workspace with many hits is one result with a count")
    func groupsRealResults() async throws {
        let store = try makeTestStore("transcript-group")
        let session = try await makeSession(store, workspace: "noisy")
        for index in 0..<12 {
            try await say(store, session, "turn \(index) mentions pelicans again")
        }

        let results = try await store.searchTranscripts("pelicans")
        #expect(results.count == 1)
        #expect(results[0].matches.count == TranscriptSearch.matchesPerWorkspace)
        #expect(results[0].total == 12)
    }
}
