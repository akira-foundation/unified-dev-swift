import Foundation
import Testing
@testable import Core

@Suite("Cancelling a message between workspaces", .tags(.persistence), .scratchDirectory)
struct WorkspaceSayCancelTests {
    @Test("the sending chat cannot cancel a message the drain has claimed or is starting a turn with")
    func noCancelOnceTheDrainHasIt() async throws {
        let f = try await WorkspaceSayFixture.make("say-cancel-drain")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        _ = await workspaceSay("Release it.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)
        let row = try #require(window.sent.first)
        let deliveryID = try #require(row.deliveryID)

        let claimed = try await f.store.claimDelivery(id: deliveryID)
        #expect(claimed)
        #expect(try await f.store.cancelWorkspaceMessage(id: row.id) == nil)

        try await f.store.beginDeliveryDispatch(id: deliveryID)
        #expect(try await f.store.cancelWorkspaceMessage(id: row.id) == nil)
        #expect(try await f.store.workspaceMessage(id: row.id)?.state == .queued)
        #expect(try await f.store.delivery(id: deliveryID) != nil)

        try await f.store.acceptDelivery(id: deliveryID)
        #expect(try await f.store.workspaceMessage(id: row.id)?.state == .delivered)
    }

    @Test("deleting an archived workspace cancels what was still queued into it")
    func deletingTheTargetCancels() async throws {
        let f = try await WorkspaceSayFixture.make("say-deleted-target")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        _ = await workspaceSay("Release it.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)
        let row = try #require(window.sent.first)

        try await f.store.update(workspaceID: f.releaser.id) { $0.archive() }
        let removed = try await f.store.deleteArchivedWorkspaces(ids: [f.releaser.id])

        #expect(removed == 1)
        #expect(try await f.store.workspaceMessage(id: row.id)?.state == .cancelled)
    }

    @Test("deleting an archived workspace cancels what it still had queued for another")
    func deletingTheSourceCancels() async throws {
        let f = try await WorkspaceSayFixture.make("say-deleted-source")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        _ = await workspaceSay("Release it.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)
        let row = try #require(window.sent.first)

        try await f.store.update(workspaceID: f.fixer.id) { $0.archive() }
        _ = try await f.store.deleteArchivedWorkspaces(ids: [f.fixer.id])

        #expect(try await f.store.workspaceMessage(id: row.id)?.state == .cancelled)
        #expect(try await f.store.pendingDeliveries(sessionID: f.releaserChat.id).isEmpty)
    }

    @Test("deleting an archived workspace leaves a delivered message delivered")
    func deletingKeepsDelivered() async throws {
        let f = try await WorkspaceSayFixture.make("say-deleted-delivered")
        let window = WorkspaceSayWindow(store: f.store, chats: f.chats)
        _ = await workspaceSay("Release it.", to: f.releaser, as: f.fixerIdentity, with: window.tool(), store: f.store)
        let row = try #require(window.sent.first)
        _ = try await f.store.markDelivered(id: try #require(row.deliveryID))

        try await f.store.update(workspaceID: f.releaser.id) { $0.archive() }
        _ = try await f.store.deleteArchivedWorkspaces(ids: [f.releaser.id])

        #expect(try await f.store.workspaceMessage(id: row.id)?.state == .delivered)
    }
}
