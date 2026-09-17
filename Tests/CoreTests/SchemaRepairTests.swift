import Foundation
import Testing
@testable import Core

@Suite("Schema repair", .tags(.persistence), .scratchDirectory)
struct SchemaRepairTests {
    @Test("a column missing from a database that calls itself migrated is put back")
    func repairsAColumnTheStampSaysIsThere() async throws {
        let path = TestScratch.unique("schema-repair") + ".sqlite"
        _ = try Store(path: path)

        let raw = try SQLiteDatabase(path: path)
        try raw.execute("DROP INDEX IF EXISTS sessions_parent;")
        try raw.execute("ALTER TABLE sessions DROP COLUMN parent_session_id;")
        let before = try raw.query("PRAGMA table_info(sessions);")
            .compactMap { $0.string("name") }
        #expect(!before.contains("parent_session_id"))

        let reopened = try Store(path: path)
        let sessions = try await reopened.sessions(workspaceID: WorkspaceID("nothing"))
        #expect(sessions.isEmpty)

        let after = try SQLiteDatabase(path: path)
        let columns = try after.query("PRAGMA table_info(sessions);")
            .compactMap { $0.string("name") }
        #expect(columns.contains("parent_session_id"))
    }
}
