import Foundation
import Testing
@testable import Core

@Suite("Workspace messages left behind by an older database", .tags(.persistence), .scratchDirectory)
struct WorkspaceSayBackfillTests {
    private func rewind(_ path: String) throws {
        let raw = try SQLiteDatabase(path: path)
        let version = try raw.readUserVersion()
        try raw.setUserVersion(version - 1)
    }

    private func writeMessage(
        _ raw: SQLiteDatabase, id: String, deliveryID: String?, deliveryState: String?
    ) throws {
        if let deliveryID, let deliveryState {
            _ = try raw.run(
                """
                INSERT INTO deliveries (id, target_session_id, body, created_at, delivery_state, delivered_at)
                VALUES (?, 'chat', 'body', 1000.0, ?, ?)
                """,
                [.text(deliveryID), .text(deliveryState), deliveryState == "accepted" ? .double(2000.0) : .null]
            )
        }
        _ = try raw.run(
            """
            INSERT INTO workspace_messages (id, body, delivery_id, state, created_at)
            VALUES (?, 'body', ?, 'queued', 1000.0)
            """,
            [.text(id), deliveryID.map { .text($0) } ?? .null]
        )
    }

    private func state(_ path: String, _ id: String) throws -> String? {
        try SQLiteDatabase(path: path)
            .query("SELECT state FROM workspace_messages WHERE id = ?", [.text(id)])
            .first?.string("state")
    }

    @Test("a message its delivery already accepted reads as delivered, with the time it went")
    func acceptedBecomesDelivered() throws {
        let path = TestScratch.unique("say-backfill-accepted") + ".sqlite"
        _ = try Store(path: path)
        try writeMessage(try SQLiteDatabase(path: path), id: "m1", deliveryID: "d1", deliveryState: "accepted")
        try rewind(path)

        _ = try Store(path: path)

        let row = try #require(try SQLiteDatabase(path: path)
            .query("SELECT * FROM workspace_messages WHERE id = 'm1'").first)
        #expect(row.string("state") == "delivered")
        #expect(row.double("delivered_at") == 2000.0)
    }

    @Test("a message whose delivery is still waiting is left alone")
    func pendingStaysQueued() throws {
        let path = TestScratch.unique("say-backfill-pending") + ".sqlite"
        _ = try Store(path: path)
        try writeMessage(try SQLiteDatabase(path: path), id: "m1", deliveryID: "d1", deliveryState: "pending")
        try rewind(path)

        _ = try Store(path: path)

        #expect(try state(path, "m1") == "queued")
    }

    @Test("a message whose delivery has gone reads as cancelled rather than waiting for ever")
    func orphanBecomesCancelled() throws {
        let path = TestScratch.unique("say-backfill-orphan") + ".sqlite"
        _ = try Store(path: path)
        try writeMessage(try SQLiteDatabase(path: path), id: "m1", deliveryID: "gone", deliveryState: nil)
        try writeMessage(try SQLiteDatabase(path: path), id: "m2", deliveryID: nil, deliveryState: nil)
        try rewind(path)

        _ = try Store(path: path)

        #expect(try state(path, "m1") == "cancelled")
        #expect(try state(path, "m2") == "cancelled")
    }
}
