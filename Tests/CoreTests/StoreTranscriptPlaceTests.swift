import Foundation
import Testing
@testable import Core

@Suite("Store transcript places", .tags(.persistence), .scratchDirectory)
struct StoreTranscriptPlaceTests {
    private let place = TranscriptPlace(anchorSeq: 42, anchorDelta: 8.5, isAtLiveEnd: true, rowCount: 90)

    private func seed(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b/w",
            path: TestScratch.unique("w"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    @Test("a session with nothing written has no place")
    func nothingWritten() async throws {
        let store = try makeTestStore("places")
        let session = try await seed(store)
        #expect(try await store.transcriptPlace(sessionID: session.id) == nil)
    }

    @Test("a written place is read back whole")
    func roundTrip() async throws {
        let store = try makeTestStore("places")
        let session = try await seed(store)
        try await store.setTranscriptPlace(place, sessionID: session.id)
        #expect(try await store.transcriptPlace(sessionID: session.id) == place)
    }

    @Test("a later place replaces the earlier one")
    func laterWins() async throws {
        let store = try makeTestStore("places")
        let session = try await seed(store)
        try await store.setTranscriptPlace(place, sessionID: session.id)
        let later = TranscriptPlace(anchorSeq: 7, anchorDelta: 0, isAtLiveEnd: false, rowCount: 91)
        try await store.setTranscriptPlace(later, sessionID: session.id)
        #expect(try await store.transcriptPlace(sessionID: session.id) == later)
    }

    @Test("a place leaves with its session")
    func goesWithTheSession() async throws {
        let store = try makeTestStore("places")
        let session = try await seed(store)
        try await store.setTranscriptPlace(place, sessionID: session.id)
        try await store.deleteSession(id: session.id)
        #expect(try await store.transcriptPlace(sessionID: session.id) == nil)
    }

    @Test("two sessions keep a place each")
    func eachSessionHasItsOwn() async throws {
        let store = try makeTestStore("places")
        let first = try await seed(store)
        let second = try await seed(store)
        let other = TranscriptPlace(anchorSeq: 7, anchorDelta: 0, isAtLiveEnd: false, rowCount: 91)
        try await store.setTranscriptPlace(place, sessionID: first.id)
        try await store.setTranscriptPlace(other, sessionID: second.id)
        #expect(try await store.transcriptPlace(sessionID: first.id) == place)
        #expect(try await store.transcriptPlace(sessionID: second.id) == other)
    }
}
