import Testing
import Foundation
@testable import Core

@Suite("A pull request read against what was seen open", .tags(.persistence), .scratchDirectory)
struct MergeArchiveReadTests {
    private func pullRequest(_ number: Int, _ state: String) -> PullRequest {
        PullRequest(
            number: number,
            title: "Archive on merge",
            url: "https://github.com/akira-foundation/unified-dev-swift/pull/\(number)",
            state: state,
            branch: "feat/337-archive-on-merge",
            closedAt: state == "OPEN" ? nil : Date()
        )
    }

    private func seed(_ store: Store) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "valencia", path: TestScratch.unique("repo")))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: "valencia", branch: "feat/337-archive-on-merge",
            path: TestScratch.unique("worktree"), baseBranch: "develop"
        ))
    }

    private func note(
        _ pullRequest: PullRequest, _ workspace: Workspace, _ store: Store,
        isEnabled: Bool = true, isAgentMidTurn: Bool = false
    ) async throws -> MergeArchiveDecision {
        try await MergeArchiveRead.note(
            pullRequest, workspaceID: workspace.id, isEnabled: isEnabled,
            isAgentMidTurn: isAgentMidTurn, store: store
        )
    }

    @Test("an open read is written down and changes nothing else")
    func openIsRecorded() async throws {
        let store = try makeTestStore("merge-read-open")
        let workspace = try await seed(store)
        #expect(try await note(pullRequest(11, "OPEN"), workspace, store) == .leave)
        #expect(try await store.pullRequestSeenOpen(workspaceID: workspace.id) == 11)
    }

    @Test("the merge of what was seen open archives once, however often it is read")
    func archivesOnce() async throws {
        let store = try makeTestStore("merge-read-once")
        let workspace = try await seed(store)
        _ = try await note(pullRequest(11, "OPEN"), workspace, store)

        #expect(try await note(pullRequest(11, "MERGED"), workspace, store) == .archiveNow)
        #expect(try await note(pullRequest(11, "MERGED"), workspace, store) == .leave)
    }

    @Test("a merge mid turn waits and keeps the record, so a relaunch still finds it")
    func midTurnKeepsTheRecord() async throws {
        let store = try makeTestStore("merge-read-mid-turn")
        let workspace = try await seed(store)
        _ = try await note(pullRequest(11, "OPEN"), workspace, store)

        #expect(try await note(pullRequest(11, "MERGED"), workspace, store, isAgentMidTurn: true) == .archiveAfterTurn)
        #expect(try await store.pullRequestSeenOpen(workspaceID: workspace.id) == 11)
        #expect(try await note(pullRequest(11, "MERGED"), workspace, store) == .archiveNow)
    }

    @Test("with the setting off the merge is forgotten")
    func offForgets() async throws {
        let store = try makeTestStore("merge-read-off")
        let workspace = try await seed(store)
        _ = try await note(pullRequest(11, "OPEN"), workspace, store)

        #expect(try await note(pullRequest(11, "MERGED"), workspace, store, isEnabled: false) == .forget)
        #expect(try await store.pullRequestSeenOpen(workspaceID: workspace.id) == nil)
        #expect(try await note(pullRequest(11, "MERGED"), workspace, store) == .leave)
    }

    @Test("a merge never seen open is left alone")
    func unseenMergeIsLeft() async throws {
        let store = try makeTestStore("merge-read-unseen")
        let workspace = try await seed(store)
        #expect(try await note(pullRequest(11, "MERGED"), workspace, store) == .leave)
    }
}
