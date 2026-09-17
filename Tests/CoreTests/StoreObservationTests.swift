import Testing
import Foundation
import Synchronization
@testable import Core

@Suite("Store change feed", .tags(.persistence), .scratchDirectory)
struct StoreObservationTests {
    @Test("a write names the table it landed in")
    func writeNamesItsTable() async throws {
        let store = try makeTestStore("changes")
        let listener = try await Listener(store)

        _ = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))

        #expect(await listener.nextBatch() == [.repos])
        listener.stop()
    }

    @Test("an upsert over a row that already exists ticks the same domain")
    func upsertOverExistingRow() async throws {
        let store = try makeTestStore("changes")
        var repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let listener = try await Listener(store)

        repo.name = "renamed"
        _ = try await store.upsert(repo)

        #expect(await listener.nextBatch() == [.repos])
        listener.stop()
    }

    @Test("a transaction is a single change, published after the commit")
    func transactionPublishesOnceAfterCommit() async throws {
        let store = try makeTestStore("changes")
        let database = try SQLiteDatabase(path: store.path)
        let listener = try await Listener(store)

        try database.transaction {
            try database.run(
                "INSERT INTO repos (id, name, path, created_at) VALUES (?, ?, ?, ?)",
                [.text("r1"), .text("one"), .text("/tmp/one"), .double(1)]
            )
            try database.run(
                """
                INSERT INTO workspaces (id, repo_id, name, branch, path, base_branch,
                    created_at, last_activity_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    .text("w1"), .text("r1"), .text("work"), .text("b"), .text("/tmp/w"),
                    .text("main"), .double(1), .double(1),
                ]
            )
        }

        #expect(await listener.nextBatch() == [.repos, .workspaces])
        #expect(await listener.nothingFurther())
        listener.stop()
    }

    @Test("a transaction that rolls back says nothing")
    func rollbackPublishesNothing() async throws {
        let store = try makeTestStore("changes")
        let database = try SQLiteDatabase(path: store.path)
        let listener = try await Listener(store)

        struct Abandoned: Error {}
        #expect(throws: Abandoned.self) {
            try database.transaction {
                try database.run(
                    "INSERT INTO repos (id, name, path, created_at) VALUES (?, ?, ?, ?)",
                    [.text("r1"), .text("one"), .text("/tmp/one"), .double(1)]
                )
                throw Abandoned()
            }
        }

        #expect(await listener.nothingFurther())

        _ = try await store.upsert(Repo(name: "two", path: TestScratch.unique("repo")))
        #expect(await listener.nextBatch() == [.repos])
        listener.stop()
    }

    @Test("a cascade delete ticks every table it emptied")
    func cascadeTicksChildTables() async throws {
        let store = try makeTestStore("changes")
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "work", branch: "b",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "chat"))
        _ = try await store.appendNext(sessionID: session.id, kind: .user, payload: Data("hi".utf8))

        let listener = try await Listener(store)
        try await store.deleteRepo(id: repo.id)

        #expect(await listener.nextBatch() == [.repos, .workspaces, .sessions, .messages])
        listener.stop()
    }

    @Test("a slow consumer is given one merged batch, not one batch per write")
    func slowConsumerSeesMergedBatches() async throws {
        let store = try makeTestStore("changes")
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let listener = try await Listener(store, handlerDelay: .milliseconds(120))

        for index in 0..<20 {
            _ = try await store.upsert(Workspace(
                repoID: repo.id, name: "w\(index)", branch: "b\(index)",
                path: TestScratch.unique("worktree"), baseBranch: "main"
            ))
        }

        await waitUntil("the feed has gone quiet") { await listener.hasSettled(for: .milliseconds(400)) }
        let batches = listener.batches
        #expect(!batches.isEmpty, "twenty writes and the consumer heard nothing")
        #expect(batches.count < 20, "twenty writes produced \(batches.count) batches, so nothing merged")
        #expect(batches.allSatisfy { $0 == [.workspaces] })
        listener.stop()
    }

    @Test("a subscriber is not woken by a table it did not ask for")
    func interestFiltersAtTheSource() async throws {
        let store = try makeTestStore("changes")
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "work", branch: "b",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id, title: "chat"))
        let listener = try await Listener(store, interest: [.repos, .workspaces])

        for index in 0..<10 {
            _ = try await store.appendNext(
                sessionID: session.id, kind: .assistantText, payload: Data("chunk \(index)".utf8)
            )
        }
        #expect(await listener.nothingFurther())

        _ = try await store.upsert(Repo(name: "two", path: TestScratch.unique("repo")))
        #expect(await listener.nextBatch() == [.repos])
        listener.stop()
    }

    @Test("reordering workspaces is announced once, not once per row")
    func workspaceReorderIsOneChange() async throws {
        let store = try makeTestStore("changes")
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        var workspaces: [Workspace] = []
        for index in 0..<8 {
            workspaces.append(try await store.upsert(Workspace(
                repoID: repo.id, name: "w\(index)", branch: "b\(index)",
                path: TestScratch.unique("worktree"), baseBranch: "main",
                sortOrder: index
            )))
        }
        let changes = SidebarReorder.move(
            visible: workspaces, all: workspaces, from: IndexSet(integer: 0), to: 8
        )
        #expect(changes.count == 8, "the drag under test has to write more than one row")

        let listener = try await Listener(store, interest: [.workspaces])
        try await store.reorderWorkspaces(changes)

        #expect(await listener.nextBatch() == [.workspaces])
        #expect(await listener.nothingFurther())
        #expect(listener.batches.count == 1, "eight rows moved, \(listener.batches.count) batches")

        let stored = try await store.workspaces(repoID: repo.id).map(\.name)
        #expect(stored == ["w1", "w2", "w3", "w4", "w5", "w6", "w7", "w0"])
        listener.stop()
    }

    @Test("reordering projects is announced once, not once per row")
    func projectReorderIsOneChange() async throws {
        let store = try makeTestStore("changes")
        var repos: [Repo] = []
        for index in 0..<5 {
            repos.append(try await store.upsert(Repo(
                name: "p\(index)", path: TestScratch.unique("repo"), sortOrder: index
            )))
        }
        let changes = SidebarReorder.move(projects: repos, id: repos[0].id, to: 5)
        #expect(changes.count == 5, "the drag under test has to write more than one row")

        let listener = try await Listener(store, interest: [.repos])
        try await store.reorderProjects(changes)

        #expect(await listener.nextBatch() == [.repos])
        #expect(await listener.nothingFurther())
        #expect(listener.batches.count == 1, "five rows moved, \(listener.batches.count) batches")

        #expect(try await store.repos().map(\.name) == ["p1", "p2", "p3", "p4", "p0"])
        listener.stop()
    }

    @Test("cancelling the task iterating a feed takes the subscription with it")
    func cancellationUnsubscribes() async throws {
        let store = try makeTestStore("changes")
        let hub = store.changeHub
        let listener = try await Listener(store)
        #expect(hub.subscriberCount == 1)

        listener.stop()

        await waitUntil("the subscription is gone") { hub.subscriberCount == 0 }
    }

    @Test("two connections on one file publish into the same feed")
    func twoConnectionsShareAHub() async throws {
        let store = try makeTestStore("changes")
        let listener = try await Listener(store)
        let second = try Store(path: store.path)

        _ = try await second.upsert(Repo(name: "one", path: TestScratch.unique("repo")))

        #expect(await listener.nextBatch() == [.repos])
        listener.stop()
    }

    @Test("in-memory stores each get a feed of their own")
    func inMemoryStoresDoNotShare() async throws {
        let first = try Store.inMemory()
        let second = try Store.inMemory()
        let listener = try await Listener(first)

        _ = try await second.upsert(Repo(name: "one", path: "/tmp/only-in-second"))
        #expect(await listener.nothingFurther())

        _ = try await first.upsert(Repo(name: "two", path: "/tmp/in-first"))
        #expect(await listener.nextBatch() == [.repos])
        listener.stop()
    }

    @Test("an update writing identical values still fires the hook")
    func identicalUpdateStillFires() async throws {
        let store = try makeTestStore("changes")
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let database = try SQLiteDatabase(path: store.path)
        let listener = try await Listener(store)

        try database.run("UPDATE repos SET name = name WHERE id = ?", [.text(repo.id)])

        #expect(await listener.nextBatch() == [.repos])
        listener.stop()
    }

    @Test("a diff stat that has not moved is not a write and not a change")
    func unchangedDiffStatIsSilent() async throws {
        let store = try makeTestStore("changes")
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "work", branch: "b",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let listener = try await Listener(store)

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 12, deletions: 3, files: 2)
        #expect(await listener.nextBatch() == [.workspaces])

        for _ in 0..<5 {
            try await store.updateDiffStat(
                workspaceID: workspace.id, additions: 12, deletions: 3, files: 2
            )
        }
        #expect(await listener.nothingFurther())

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 13, deletions: 3, files: 2)
        #expect(await listener.nextBatch() == [.workspaces])

        let reread = try await store.workspace(id: workspace.id)
        #expect(reread?.additions == 13)
        listener.stop()
    }

    @Test("a delete of every row still ticks, because foreign keys are on")
    func truncateOptimisationIsDefeated() async throws {
        let store = try makeTestStore("changes")
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "work", branch: "b",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        _ = try await store.upsert(ReviewComment(
            workspaceID: workspace.id,
            filePath: "a.swift",
            anchor: ReviewCommentAnchor(line: 1, text: "let a = 1"),
            body: "note"
        ))
        let database = try SQLiteDatabase(path: store.path)
        let listener = try await Listener(store)

        try database.run("DELETE FROM review_comments")

        #expect(await listener.nextBatch() == [.reviewComments])
        listener.stop()
    }
}

private final class Listener: Sendable {
    private struct State {
        var batches: [Set<StoreDomain>] = []
        var taken = 0
        var task: Task<Void, Never>?
    }

    private let state = Mutex(State())

    init(
        _ store: Store,
        interest: Set<StoreDomain> = Set(StoreDomain.allCases),
        handlerDelay: Duration? = nil
    ) async throws {
        let hub = store.changeHub
        let before = hub.subscriberCount
        let feed = store.changes(of: interest)
        let task = Task { [self] in
            for await batch in feed {
                state.withLock { $0.batches.append(batch) }
                if let handlerDelay { try? await Task.sleep(for: handlerDelay) }
            }
        }
        state.withLock { $0.task = task }
        await waitUntil("the listener has subscribed") { hub.subscriberCount > before }
    }

    var batches: [Set<StoreDomain>] {
        state.withLock { $0.batches }
    }

    func nextBatch(within timeout: Duration = .seconds(3)) async -> Set<StoreDomain>? {
        let seen = state.withLock { $0.taken }
        await waitUntil("a batch arrives", within: timeout) { self.batches.count > seen }
        return state.withLock { state in
            guard state.batches.count > seen else { return nil }
            state.taken = seen + 1
            return state.batches[seen]
        }
    }

    func nothingFurther(within window: Duration = .milliseconds(250)) async -> Bool {
        let before = batches.count
        try? await Task.sleep(for: window)
        return batches.count == before
    }

    func hasSettled(for window: Duration) async -> Bool {
        await nothingFurther(within: window)
    }

    func stop() {
        state.withLock { $0.task }?.cancel()
    }

    deinit {
        state.withLock { $0.task }?.cancel()
    }
}
