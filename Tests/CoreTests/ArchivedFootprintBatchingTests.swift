import Foundation
import Synchronization
import Testing
@testable import Core

@Suite("Archived footprint batching", .tags(.persistence), .scratchDirectory)
struct ArchivedFootprintBatchingTests {
    private let batch = ArchivedWorkspaceFootprint.measuringBatch

    @Test("a session is measured in batches of the ceiling and adds up across them")
    func addsUpAcrossBatches() async throws {
        let store = try makeTestStore("footprint-batches")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let archived = try await archivedWorkspace(store, repo: repo, name: "old")
        let session = try await store.upsert(Session(workspaceID: archived.id, title: "S", model: "opus"))
        try await append(store, to: session, count: batch * 2 + 3, payload: "12345")

        let pauses = PauseCount()
        let footprints = try await store.archivedFootprints(betweenBatches: { pauses.tick() })

        #expect(pauses.value == 3)
        #expect(footprints.first?.messageCount == batch * 2 + 3)
        #expect(footprints.first?.transcriptBytes == (batch * 2 + 3) * 5)
    }

    @Test("a session that ends exactly on a batch still stops")
    func stopsOnAnExactBatch() async throws {
        let store = try makeTestStore("footprint-exact")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let archived = try await archivedWorkspace(store, repo: repo, name: "old")
        let session = try await store.upsert(Session(workspaceID: archived.id, title: "S", model: "opus"))
        try await append(store, to: session, count: batch, payload: "x")

        let pauses = PauseCount()
        let footprints = try await store.archivedFootprints(betweenBatches: { pauses.tick() })

        #expect(pauses.value == 2)
        #expect(footprints.first?.messageCount == batch)
    }

    @Test("a live workspace's transcript is not read")
    func leavesLiveTranscriptsAlone() async throws {
        let store = try makeTestStore("footprint-live")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let live = try await store.upsert(Workspace(
            repoID: repo.id, name: "live", branch: "live", path: "/tmp/live", baseBranch: "main"
        ))
        let liveSession = try await store.upsert(Session(workspaceID: live.id, title: "S", model: "opus"))
        try await append(store, to: liveSession, count: batch * 3, payload: "x")
        let archived = try await archivedWorkspace(store, repo: repo, name: "old")
        _ = try await store.upsert(Session(workspaceID: archived.id, title: "S", model: "opus"))

        let pauses = PauseCount()
        _ = try await store.archivedFootprints(betweenBatches: { pauses.tick() })

        #expect(pauses.value == 1)
    }

    @Test("two sessions of a workspace add up, and each has its own batches")
    func addsUpAcrossSessions() async throws {
        let store = try makeTestStore("footprint-sessions")
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let archived = try await archivedWorkspace(store, repo: repo, name: "old")
        let first = try await store.upsert(Session(workspaceID: archived.id, title: "A", model: "opus"))
        let second = try await store.upsert(Session(workspaceID: archived.id, title: "B", model: "opus"))
        try await append(store, to: first, count: 2, payload: "12345")
        try await append(store, to: second, count: 3, payload: "12")

        let pauses = PauseCount()
        let footprints = try await store.archivedFootprints(betweenBatches: { pauses.tick() })

        #expect(pauses.value == 2)
        #expect(footprints.first?.messageCount == 5)
        #expect(footprints.first?.transcriptBytes == 16)
    }

    private func archivedWorkspace(_ store: Store, repo: Repo, name: String) async throws -> Workspace {
        var workspace = Workspace(repoID: repo.id, name: name, branch: name, path: "/tmp/\(name)", baseBranch: "main")
        _ = try await store.upsert(workspace)
        workspace.archive()
        workspace.archivedAt = Date()
        return try await store.upsert(workspace)
    }

    private func append(_ store: Store, to session: Session, count: Int, payload: String) async throws {
        for _ in 0..<count {
            try await store.appendNext(sessionID: session.id, kind: .assistantText, payload: Data(payload.utf8))
        }
    }
}

private final class PauseCount: Sendable {
    private let count = Mutex(0)
    var value: Int { count.withLock { $0 } }
    func tick() { count.withLock { $0 += 1 } }
}
