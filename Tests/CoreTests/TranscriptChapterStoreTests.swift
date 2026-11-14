import Foundation
import Testing
@testable import Core

@Suite("Transcript chapter store", .tags(.persistence), .scratchDirectory)
struct TranscriptChapterStoreTests {
    private func makeSession(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    private func said(_ text: String) -> Data {
        Data(#"{"type":"user","message":{"content":"\#(text)"}}"#.utf8)
    }

    @Test func pinnedChaptersReadBackInConversationOrder() async throws {
        let store = try makeTestStore("chapters-order")
        let session = try await makeSession(store)
        try await store.pin(TranscriptChapter(seq: 7, title: "later"), sessionID: session.id)
        try await store.pin(TranscriptChapter(seq: 2, title: "earlier"), sessionID: session.id)

        #expect(try await store.chapters(sessionID: session.id) == [
            TranscriptChapter(seq: 2, title: "earlier"), TranscriptChapter(seq: 7, title: "later"),
        ])
    }

    @Test func pinningTheSameMessageTwiceKeepsOneChapter() async throws {
        let store = try makeTestStore("chapters-twice")
        let session = try await makeSession(store)
        try await store.pin(TranscriptChapter(seq: 3, title: "old"), sessionID: session.id)
        try await store.pin(TranscriptChapter(seq: 3, title: "new"), sessionID: session.id)

        #expect(try await store.chapters(sessionID: session.id) == [TranscriptChapter(seq: 3, title: "new")])
    }

    @Test func unpinningRemovesOnlyThatChapter() async throws {
        let store = try makeTestStore("chapters-unpin")
        let session = try await makeSession(store)
        let other = try await makeSession(store)
        try await store.pin(TranscriptChapter(seq: 1, title: "one"), sessionID: session.id)
        try await store.pin(TranscriptChapter(seq: 4, title: "four"), sessionID: session.id)
        try await store.pin(TranscriptChapter(seq: 1, title: "elsewhere"), sessionID: other.id)

        try await store.unpinChapter(seq: 1, sessionID: session.id)

        #expect(try await store.chapters(sessionID: session.id) == [TranscriptChapter(seq: 4, title: "four")])
        #expect(try await store.chapters(sessionID: other.id) == [TranscriptChapter(seq: 1, title: "elsewhere")])
    }

    @Test func deletingAChatTakesItsChapters() async throws {
        let store = try makeTestStore("chapters-cascade")
        let session = try await makeSession(store)
        try await store.pin(TranscriptChapter(seq: 1, title: "one"), sessionID: session.id)

        try await store.deleteSession(id: session.id)

        #expect(try await store.chapters(sessionID: session.id).isEmpty)
    }
}
