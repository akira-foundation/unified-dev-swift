import Foundation
import Testing
@testable import Core

@Suite("Messages between workspaces, as far as they were delivered", .tags(.persistence), .scratchDirectory)
struct WorkspaceSayDeliveryTests {
    @Test("the record follows the drain: claimed and dispatching stay queued, accepted is delivered")
    func followsTheDrain() async throws {
        let f = try await WorkspaceSayFixture.make("say-drain")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        _ = await workspaceSay("Release it.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)
        let row = try #require(window.sent.first)
        let deliveryID = try #require(row.deliveryID)

        let claimed = try await f.store.claimDelivery(id: deliveryID)
        #expect(claimed)
        #expect(try await f.store.workspaceMessage(id: row.id)?.state == .queued)
        try await f.store.beginDeliveryDispatch(id: deliveryID)
        #expect(try await f.store.workspaceMessage(id: row.id)?.state == .queued)
        try await f.store.acceptDelivery(id: deliveryID)

        let delivered = try #require(try await f.store.workspaceMessage(id: row.id))
        #expect(delivered.state == .delivered)
        #expect(delivered.deliveredAt != nil)
    }

    @Test("a message still queued is not something to answer")
    func queuedIsNotHeard() async throws {
        let f = try await WorkspaceSayFixture.make("say-queued-reply")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        let tool = window.tool()
        _ = await workspaceSay("Release it.", to: f.releaser, as: f.fixerIdentity, with: tool, store: f.store)

        #expect(try await f.store.latestWorkspaceMessage(from: f.fixer.id, to: f.releaser.id) == nil)
        let reply = await workspaceSay("Released.", to: f.fixer, as: f.releaserIdentity, with: tool, store: f.store)
        #expect(!reply.isError, "\(reply.text)")
        #expect(window.sent.last?.replySessionID == nil)
    }

    @Test("an answer goes to the chat whose message was delivered, not to a later one still queued")
    func replyFollowsTheDeliveredChat() async throws {
        let f = try await WorkspaceSayFixture.make("say-delivered-reply")
        let otherChat = try await f.store.upsert(Session(workspaceID: f.fixer.id, title: "Another chat"))
        let other = BridgeIdentity(sessionID: otherChat.id, workspaceID: f.fixer.id, role: .parent)
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        let tool = window.tool()

        _ = await workspaceSay("Release it.", to: f.releaser, as: f.fixerIdentity, with: tool, store: f.store)
        let first = try #require(window.sent.last?.deliveryID)
        _ = try await f.store.markDelivered(id: first)
        _ = await workspaceSay("And the docs.", to: f.releaser, as: other, with: tool, store: f.store)
        _ = await workspaceSay("Released v4.2.3.", to: f.fixer, as: f.releaserIdentity, with: tool, store: f.store)

        #expect(window.sent.last?.replySessionID == f.fixerChat.id)
    }

    @Test("a workspace agent whose row has gone is refused, not taken for the owner's client", .tags(.security))
    func vanishedCallerIsRefused() async throws {
        let f = try await WorkspaceSayFixture.make("say-vanished")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        let ghost = BridgeIdentity(sessionID: SessionID("gone"), workspaceID: WorkspaceID("gone"), role: .parent)

        let result = await workspaceSay("Hi.", to: f.releaser, as: ghost, with: window.tool(), store: f.store)

        #expect(result.isError)
        #expect(result.text.contains("no longer has the workspace"))
        #expect(window.sent.isEmpty)
    }
}
