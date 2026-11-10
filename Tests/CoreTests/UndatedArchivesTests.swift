import Foundation
import Testing
@testable import Core

@Suite("Archived workspaces that have no archive date", .tags(.persistence), .scratchDirectory)
struct UndatedArchivesTests {
    private func workspace(_ name: String, in repo: Repo, state: WorkspaceState, archivedAt: Date? = nil) -> Workspace {
        Workspace(
            repoID: repo.id, name: name, branch: name, path: TestScratch.unique(name), baseBranch: "main",
            state: state, archivedAt: archivedAt
        )
    }

    @Test func theMigrationStartsTheClockOnlyOnArchivedRowsWithNoDate() async throws {
        let path = TestScratch.unique("undated") + ".sqlite"
        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let dated = Date(timeIntervalSince1970: 1_000_000)
        let undated = try await store.upsert(workspace("undated", in: repo, state: .archived))
        let kept = try await store.upsert(workspace("dated", in: repo, state: .archived, archivedAt: dated))
        let active = try await store.upsert(workspace("active", in: repo, state: .active))
        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)
        let before = Date()

        let reopened = try Store(path: path)

        let stamped = try #require(try await reopened.workspace(id: undated.id)?.archivedAt)
        #expect(stamped >= before.addingTimeInterval(-1))
        #expect(stamped <= Date().addingTimeInterval(1))
        #expect(try await reopened.workspace(id: kept.id)?.archivedAt == dated)
        #expect(try await reopened.workspace(id: active.id)?.archivedAt == nil)
    }

    @Test func theStampWritesTheMomentItIsGiven() throws {
        let db = try SQLiteDatabase(path: ":memory:")
        try db.execute("CREATE TABLE workspaces (state TEXT, archived_at REAL);")
        _ = try db.run("INSERT INTO workspaces (state) VALUES (?)", [.text("archived")])
        let moment = Date(timeIntervalSince1970: 2_000_000_000)

        try UndatedArchives.stamp(db, at: moment)

        #expect(try db.query("SELECT archived_at FROM workspaces").first?.date("archived_at") == moment)
    }
}
