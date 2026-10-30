import Testing
import Foundation
@testable import Core

@Suite("Where an agent's raw value is written in the database", .tags(.persistence), .scratchDirectory)
struct AgentKindColumnsTests {
    @Test("the schema itself says which columns a rename of AgentKind has to migrate")
    func theSchemaSaysWhichColumnsARenameMustMigrate() async throws {
        let store = try makeTestStore("kind-columns")

        let found = try AgentKindColumns.found(in: try SQLiteDatabase(path: store.path))

        #expect(found == AgentKindColumns.aRenameMustMigrate)
    }

    @Test("a table added with a provider column or an account of its own has to be declared")
    func anUndeclaredTableIsRefused() async throws {
        let store = try makeTestStore("kind-columns")
        let db = try SQLiteDatabase(path: store.path)

        try db.execute("""
            CREATE TABLE crew_agent_accounts (
                crew_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                account_id TEXT NOT NULL REFERENCES agent_accounts(id) ON DELETE CASCADE,
                PRIMARY KEY (crew_id, provider)
            );
            """)

        let found = try AgentKindColumns.found(in: db)

        #expect(found != AgentKindColumns.aRenameMustMigrate)
        #expect(found.subtracting(AgentKindColumns.aRenameMustMigrate)
            == ["crew_agent_accounts.provider", "crew_agent_accounts.account_id"])
    }

    @Test("an account a scope points at is found by its foreign key, whatever the column is called")
    func anAccountColumnIsFoundByItsForeignKey() async throws {
        let store = try makeTestStore("kind-columns")
        let db = try SQLiteDatabase(path: store.path)

        try db.execute("""
            CREATE TABLE crew_accounts (
                crew_id TEXT PRIMARY KEY,
                runs_under TEXT NOT NULL REFERENCES agent_accounts(id) ON DELETE CASCADE
            );
            """)

        #expect(try AgentKindColumns.found(in: db).contains("crew_accounts.runs_under"))
    }

    @Test("every declared column is one the database really has")
    func everyDeclaredColumnExists() async throws {
        let store = try makeTestStore("kind-columns")
        let db = try SQLiteDatabase(path: store.path)

        for declared in AgentKindColumns.aRenameMustMigrate {
            let parts = declared.split(separator: ".")
            let names = try db.query("PRAGMA table_info(\(parts[0]));").compactMap { $0.string("name") }
            #expect(names.contains(String(parts[1])), "\(declared) is declared but not in the schema")
        }
    }
}
