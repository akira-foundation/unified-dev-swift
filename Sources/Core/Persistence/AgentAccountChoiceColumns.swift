import Foundation

enum AgentAccountChoiceColumns {
    struct Table: Sendable {
        let name: String
        let owner: String
        let parent: String

        var createTable: String {
            """
            CREATE TABLE IF NOT EXISTS \(name) (
                \(owner) TEXT NOT NULL REFERENCES \(parent)(id) ON DELETE CASCADE,
                provider TEXT NOT NULL,
                account_id TEXT NOT NULL REFERENCES agent_accounts(id) ON DELETE CASCADE,
                PRIMARY KEY (\(owner), provider)
            );
            """
        }

        var all: String { "SELECT \(owner) AS owner, provider, account_id FROM \(name)" }

        var choose: String {
            """
            INSERT INTO \(name) (\(owner), provider, account_id) VALUES (?, ?, ?)
            ON CONFLICT(\(owner), provider) DO UPDATE SET account_id = excluded.account_id
            """
        }

        var clear: String { "DELETE FROM \(name) WHERE \(owner) = ? AND provider = ?" }

        var carry: String {
            """
            INSERT OR IGNORE INTO \(name) (\(owner), provider, account_id)
            SELECT \(parent).id, agent_accounts.provider, \(parent).account_id
            FROM \(parent) JOIN agent_accounts ON agent_accounts.id = \(parent).account_id
            WHERE \(parent).account_id IS NOT NULL;
            """
        }

        var strangers: String {
            """
            SELECT DISTINCT account_id AS id FROM \(parent)
            WHERE account_id IS NOT NULL
              AND account_id NOT IN (SELECT id FROM agent_accounts);
            """
        }

        var drop: String { "ALTER TABLE \(parent) DROP COLUMN account_id;" }
    }

    static let repos = Table(name: "repo_agent_accounts", owner: "repo_id", parent: "repos")

    static let workspaceChoiceTable = "workspace_agent_accounts"

    static func migrate(_ db: SQLiteDatabase, defaults: [AgentAccountHome]? = nil) throws {
        try db.transaction { try move(db, defaults: defaults) }
    }

    static func move(_ db: SQLiteDatabase, defaults: [AgentAccountHome]? = nil) throws {
        var homes = defaults
        if try columns(of: "workspaces", in: db).contains("account_id") {
            try db.execute("ALTER TABLE workspaces DROP COLUMN account_id;")
        }
        try db.execute(repos.createTable)
        guard try columns(of: repos.parent, in: db).contains("account_id") else { return }
        for id in try db.query(repos.strangers).compactMap({ $0.string("id") }) {
            guard let provider = AgentAccountHome.provider(ofDefaultID: AgentAccountID(id)) else { continue }
            if homes == nil { homes = SpendAccounts.defaultHomes() }
            guard let home = homes?.first(where: { $0.provider == provider }) else { continue }
            try db.run(AgentAccountColumns.insertIfMissing, AgentAccountColumns.values(AgentAccountRow(
                id: home.id, provider: provider, directory: home.directory.path, isDefault: true
            )))
        }
        try db.execute(repos.carry)
        try db.execute(repos.drop)
    }

    static func forgetWorkspaceChoices(_ db: SQLiteDatabase) throws {
        try db.execute("DROP TABLE IF EXISTS \(workspaceChoiceTable);")
    }

    private static func columns(of table: String, in db: SQLiteDatabase) throws -> Set<String> {
        Set(try db.query("PRAGMA table_info(\(table));").compactMap { $0.string("name") })
    }

    static func book(reading query: (String) throws -> [Row]) throws -> AgentAccountChoiceBook {
        var book = AgentAccountChoiceBook()
        for row in try query(repos.all) {
            guard let read = read(row) else { continue }
            book.record(read.account, of: read.provider, forRepo: RepoID(read.owner))
        }
        return book
    }

    private static func read(_ row: Row) -> (owner: String, provider: AgentKind, account: AgentAccountID)? {
        guard let owner = row.string("owner"),
              let provider = AgentKind(rawValue: row.string("provider") ?? ""),
              let account = row.string("account_id")
        else { return nil }
        return (owner, provider, AgentAccountID(account))
    }
}
