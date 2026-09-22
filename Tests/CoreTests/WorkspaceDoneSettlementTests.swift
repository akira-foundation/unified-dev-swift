import Foundation
import Testing
@testable import Core

@Suite("Settling the watches on a workspace whose turn came to rest", .tags(.persistence), .scratchDirectory)
struct WorkspaceDoneSettlementTests {
    private func ask(_ f: WorkspaceSayFixture, notify: Bool = true) async throws -> WorkspaceMessage {
        let message = WorkspaceMessage(
            source: WorkspaceMessageEnd(
                workspaceID: f.fixer.id, workspace: f.fixer.name,
                sessionID: f.fixerChat.id, chat: f.fixerChat.title
            ),
            target: WorkspaceMessageEnd(workspaceID: f.releaser.id, workspace: f.releaser.name),
            text: "Release it.",
            notifyWhenDone: notify
        )
        return try await f.store.enqueueWorkspaceMessage(message, into: f.releaserChat)
    }

    private func finish(_ f: WorkspaceSayFixture, _ ending: WorkspaceTurnEnding) async throws -> [Session] {
        try await f.store.settleWorkspaceDoneWatches(
            on: f.releaser.id, ending: ending, in: f.releaserChat.id, isSubagentChat: false
        )
    }

    private func reports(_ f: WorkspaceSayFixture) async throws -> [CrewMessage] {
        try await f.store.pendingDeliveries(sessionID: f.fixerChat.id)
            .filter { $0.kind == .report }
            .compactMap(\.crewMessage)
    }

    @Test("a delivered message's turn finishing queues one report in the asking chat, and only once")
    func deliveredIsToldOnce() async throws {
        let f = try await WorkspaceSayFixture.make("settle-once")
        let row = try await ask(f)
        _ = try await f.store.markDelivered(id: try #require(row.deliveryID))

        let first = try await finish(f, .finished(lastMessage: "Released v4.2.3."))
        let second = try await finish(f, .finished(lastMessage: "Again."))

        #expect(first.map(\.id) == [f.fixerChat.id])
        #expect(second.isEmpty)
        let told = try await reports(f)
        #expect(told.count == 1)
        #expect(told.first?.event == .workspaceDone)
        #expect(told.first?.sent.contains("Released v4.2.3.") == true)
    }

    @Test("the turn a queued message waits behind leaves the watch standing")
    func queuedWaits() async throws {
        let f = try await WorkspaceSayFixture.make("settle-queued")
        _ = try await ask(f)

        let told = try await finish(f, .finished(lastMessage: "Earlier work."))

        #expect(told.isEmpty)
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).count == 1)
    }

    @Test("a cancelled message spends its watch and says nothing")
    func cancelledIsSilent() async throws {
        let f = try await WorkspaceSayFixture.make("settle-cancelled")
        let row = try await ask(f)
        _ = try await f.store.cancelWorkspaceMessage(id: row.id)

        let told = try await finish(f, .finished(lastMessage: nil))

        #expect(told.isEmpty)
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).isEmpty)
        #expect(try await reports(f).isEmpty)
    }

    @Test("an asking chat closed in the meantime is told nothing, and the watch is spent")
    func closedChatIsNotTold() async throws {
        let f = try await WorkspaceSayFixture.make("settle-closed")
        let row = try await ask(f)
        _ = try await f.store.markDelivered(id: try #require(row.deliveryID))
        _ = try await f.store.update(sessionID: f.fixerChat.id) { $0.archivedAt = Date() }

        let told = try await finish(f, .failed(reason: "Credentials expired."))

        #expect(told.isEmpty)
        #expect(try await f.store.unspentWorkspaceDoneWatches(targetWorkspaceID: f.releaser.id).isEmpty)
    }

    @Test("archiving tells a message that was never read, whatever chat it waited in")
    func archivedTellsTheUnread() async throws {
        let f = try await WorkspaceSayFixture.make("settle-archived")
        _ = try await ask(f)

        let told = try await f.store.settleWorkspaceDoneWatches(
            on: f.releaser.id, ending: .archived, in: nil, isSubagentChat: false
        )

        #expect(told.map(\.id) == [f.fixerChat.id])
        #expect(try await reports(f).first?.text == "release was archived before it read the message")
    }
}
