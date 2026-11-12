import Testing
import Foundation
@testable import Core

@Suite("Diff stat publication", .tags(.persistence), .scratchDirectory)
struct DiffStatPublicationTests {
    private func seeded(_ store: Store) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "one", path: TestScratch.unique("repo")))
        let workspace = Workspace(
            repoID: repo.id, name: "work", branch: "b",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        )
        try await store.upsert(workspace)
        return workspace
    }

    @Test("a diff stat write wakes nothing a project reload listens to")
    func diffStatWriteSkipsTheReloadDomains() async throws {
        let store = try makeTestStore("diffstat")
        let workspace = try await seeded(store)
        let reload = try await StoreChangeListener(
            store, interest: StoreDomain.projectsWorkspacesAndTheirAccounts
        )
        let counts = try await StoreChangeListener(store, interest: [.diffStats])

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 3, deletions: 1, files: 2)

        #expect(await counts.nextBatch() == [.diffStats])
        #expect(await reload.nothingFurther())
        reload.stop()
        counts.stop()
    }

    @Test("a relabelled write inside a transaction keeps the other tables it touched")
    func relabelInsideTransactionKeepsOthers() async throws {
        let store = try makeTestStore("diffstat")
        let workspace = try await seeded(store)
        let database = try SQLiteDatabase(path: store.path)
        let listener = try await StoreChangeListener(store)

        try database.transaction {
            try database.run(
                "INSERT INTO repos (id, name, path, created_at) VALUES (?, ?, ?, ?)",
                [.text("r2"), .text("two"), .text("/tmp/two"), .double(1)]
            )
            try database.run(
                "UPDATE workspaces SET additions = 9 WHERE id = ?",
                [.text(workspace.id)],
                publishing: [.diffStats]
            )
        }

        #expect(await listener.nextBatch() == [.repos, .diffStats])
        listener.stop()
    }

    @Test("the counts read back are the ones written")
    func diffStatsReadBack() async throws {
        let store = try makeTestStore("diffstat")
        let workspace = try await seeded(store)

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 7, deletions: 4, files: 3)

        let stats = try await store.diffStats()
        #expect(stats[workspace.id] == WorkspaceDiffStat(additions: 7, deletions: 4, files: 3))
    }

    @Test("applying counts that match the list changes nothing")
    func applyingEqualCountsIsNil() {
        let workspace = Workspace(
            repoID: RepoID("r"), name: "w", branch: "b", path: "/w", baseBranch: "main",
            additions: 1, deletions: 2, changedFiles: 3
        )
        let stats = [workspace.id: WorkspaceDiffStat(additions: 1, deletions: 2, files: 3)]

        #expect(WorkspaceDiffStat.applied(stats, to: [workspace]) == nil)
    }

    @Test("applying counts changes only the workspace whose counts moved")
    func applyingChangesOnlyTheMovedWorkspace() throws {
        let still = Workspace(repoID: RepoID("r"), name: "still", branch: "a", path: "/a", baseBranch: "main")
        let moved = Workspace(repoID: RepoID("r"), name: "moved", branch: "b", path: "/b", baseBranch: "main")
        let stats = [
            still.id: WorkspaceDiffStat(of: still),
            moved.id: WorkspaceDiffStat(additions: 5, deletions: 6, files: 2),
        ]

        let updated = try #require(WorkspaceDiffStat.applied(stats, to: [still, moved]))

        #expect(updated[0] == still)
        #expect(updated[1].additions == 5)
        #expect(updated[1].deletions == 6)
        #expect(updated[1].changedFiles == 2)
        #expect(updated[1].name == "moved")
    }

    @Test("the project list feed covers every domain a reload reads, and diff stats beside them")
    func projectListFeedCoversReloadAndCounts() {
        #expect(StoreDomain.projectListFeed.isSuperset(of: StoreDomain.projectsWorkspacesAndTheirAccounts))
        #expect(StoreDomain.projectListFeed.contains(.diffStats))
    }

    @Test("a batch of counts alone is answered without a reload")
    func countsAloneSkipTheReload() {
        #expect(ProjectListRefresh(answering: [.diffStats]) == .diffStatsOnly)
    }

    @Test("a batch naming any reload domain reloads, counts or not", arguments: [
        Set<StoreDomain>([.workspaces]),
        [.repos, .diffStats],
        [.repoAgentAccounts],
        [.profileAgentAccounts, .diffStats],
    ])
    func anyReloadDomainReloads(batch: Set<StoreDomain>) {
        #expect(ProjectListRefresh(answering: batch) == .reload)
    }
}
