import Foundation
import Testing
@testable import Core

@Suite("Watches for another workspace's turn, in the store", .tags(.persistence), .scratchDirectory)
struct WorkspaceDoneWatchStoreTests {
    private func message(_ f: WorkspaceSayFixture, notify: Bool) -> WorkspaceMessage {
        WorkspaceMessage(
            source: WorkspaceMessageEnd(
                workspaceID: f.fixer.id, workspace: f.fixer.name,
                sessionID: f.fixerChat.id, chat: f.fixerChat.title
            ),
            target: WorkspaceMessageEnd(workspaceID: f.releaser.id, workspace: f.releaser.name),
            text: "Release it.",
            notifyWhenDone: notify
        )
    }

    @Test("a message asking to be told writes its watch with it, and the watch follows the message")
    func watchFollowsTheMessage() async throws {
        let f = try await WorkspaceSayFixture.make("done-follows")
        let row = try await f.store.enqueueWorkspaceMessage(message(f, notify: true), into: f.releaserChat)
        _ = try await f.store.enqueueWorkspaceMessage(message(f, notify: false), into: f.releaserChat)

        #expect(row.notifyWhenDone)
        let watches = try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id)
        let queued = try #require(watches.first)
        #expect(watches.count == 1)
        #expect(queued.cause == .message(row.id, state: .queued))
        #expect(queued.watcherSessionID == f.fixerChat.id)
        #expect(queued.target.sessionID == f.releaserChat.id)

        _ = try await f.store.markDelivered(id: try #require(row.deliveryID))
        let delivered = try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id)
        #expect(delivered.first?.cause == .message(row.id, state: .delivered))
    }

    @Test("a watch is spent by exactly one claim, and a spent one is no longer listed")
    func claimedOnce() async throws {
        let f = try await WorkspaceSayFixture.make("done-once")
        _ = try await f.store.enqueueWorkspaceMessage(message(f, notify: true), into: f.releaserChat)
        let watch = try #require(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).first)

        let first = try await f.store.claimWorkspaceDoneWatch(id: watch.id)
        let second = try await f.store.claimWorkspaceDoneWatch(id: watch.id)

        #expect(first)
        #expect(!second)
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).isEmpty)
        #expect(try await f.store.workspaceDoneWatch(id: watch.id)?.notifiedAt != nil)
    }

    @Test("a cancelled message's watch reads as cancelled, which spends it silently")
    func cancelledReadsBack() async throws {
        let f = try await WorkspaceSayFixture.make("done-cancelled")
        let row = try await f.store.enqueueWorkspaceMessage(message(f, notify: true), into: f.releaserChat)
        _ = try await f.store.cancelWorkspaceMessage(id: row.id)

        let watch = try #require(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).first)

        let verdict = watch.verdict(on: .finished(lastMessage: nil), in: f.releaserChat.id, isSubagentChat: false)
        #expect(verdict == .discard)
    }

    @Test("a watch with no message is a start's, and is listed the same way")
    func startWatch() async throws {
        let f = try await WorkspaceSayFixture.make("done-start-row")
        try await f.store.addWorkspaceDoneWatch(WorkspaceDoneWatch(
            cause: .start,
            watcherSessionID: f.fixerChat.id,
            target: WorkspaceMessageEnd(
                workspaceID: f.releaser.id, workspace: f.releaser.name,
                sessionID: f.releaserChat.id, chat: f.releaserChat.title
            )
        ))

        let watch = try #require(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).first)
        #expect(watch.cause == .start)
        #expect(watch.target.chat == f.releaserChat.title)
    }

    @Test("the migration replays over a database that already has the table and the column")
    func migrationReplays() async throws {
        let path = TestScratch.unique("done-migrate") + ".sqlite"
        _ = try Store(path: path)
        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(try raw.readUserVersion() - 1)

        let reopened = try Store(path: path)

        #expect(try await reopened.unspentWorkspaceDoneWatches(targetWorkspaceID: WorkspaceID("none")).isEmpty)
    }

    @Test("a database from before the migration gains the table and the column")
    func migrationAddsThem() async throws {
        let path = TestScratch.unique("done-old") + ".sqlite"
        _ = try Store(path: path)
        let raw = try SQLiteDatabase(path: path)
        try raw.execute("DROP TABLE workspace_done_watches;")
        try raw.execute("ALTER TABLE workspace_messages DROP COLUMN notify_when_done;")
        try raw.setUserVersion(try raw.readUserVersion() - 1)

        let reopened = try Store(path: path)
        let repo = try await reopened.upsert(Repo(name: "apex", path: TestScratch.unique("repo")))
        let fixer = try await reopened.upsert(Workspace(
            repoID: repo.id, name: "fixer", branch: "apex/fix", path: TestScratch.unique("fixer"), baseBranch: "main"
        ))
        let releaser = try await reopened.upsert(Workspace(
            repoID: repo.id, name: "releaser", branch: "apex/release", path: TestScratch.unique("releaser"), baseBranch: "main"
        ))
        let fixerChat = try await reopened.upsert(Session(workspaceID: fixer.id, title: "Chat"))
        let releaserChat = try await reopened.upsert(Session(workspaceID: releaser.id, title: "Release"))

        let row = try await reopened.enqueueWorkspaceMessage(
            WorkspaceMessage(
                source: WorkspaceMessageEnd(
                    workspaceID: fixer.id, workspace: "fixer", sessionID: fixerChat.id, chat: "Chat"
                ),
                target: WorkspaceMessageEnd(workspaceID: releaser.id, workspace: "releaser"),
                text: "Release it.",
                notifyWhenDone: true
            ),
            into: releaserChat
        )

        #expect(row.notifyWhenDone)
        #expect(try await reopened.unspentWorkspaceDoneWatches(targetWorkspaceID: releaser.id).count == 1)
    }
}
