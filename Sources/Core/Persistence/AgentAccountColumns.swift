import Foundation

enum AgentAccountColumns {
    static let pointingTables = ["sessions"]

    static let profileColumn = "profile_id"

    static func migrate(_ db: SQLiteDatabase) throws {
        try db.execute(createTable)
        let own = Set(try db.query("PRAGMA table_info(agent_accounts);").compactMap { $0.string("name") })
        if !own.contains(profileColumn) {
            try db.execute(
                "ALTER TABLE agent_accounts ADD COLUMN \(profileColumn) TEXT NOT NULL DEFAULT '\(ProfileID.initial.rawValue)';"
            )
        }
        for table in pointingTables {
            let columns = Set(try db.query("PRAGMA table_info(\(table));").compactMap { $0.string("name") })
            guard !columns.isEmpty, !columns.contains("account_id") else { continue }
            try db.execute("ALTER TABLE \(table) ADD COLUMN account_id TEXT REFERENCES agent_accounts(id) ON DELETE SET NULL;")
        }
    }

    static let createTable = """
        CREATE TABLE IF NOT EXISTS agent_accounts (
            id TEXT PRIMARY KEY,
            provider TEXT NOT NULL,
            directory TEXT NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0,
            label TEXT NOT NULL DEFAULT '',
            created_at REAL NOT NULL,
            profile_id TEXT NOT NULL DEFAULT '\(ProfileID.initial.rawValue)'
        );
        """

    static let all = "SELECT * FROM agent_accounts ORDER BY created_at, rowid"

    private static let insertion = """
        INTO agent_accounts (id, provider, directory, is_default, label, created_at, profile_id)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """

    static let insert = "INSERT " + insertion

    static let insertIfMissing = "INSERT OR IGNORE " + insertion

    static let delete = "DELETE FROM agent_accounts WHERE id = ?"

    static func release(_ table: String) -> String {
        "UPDATE \(table) SET account_id = NULL WHERE account_id = ?"
    }

    static func choose(_ table: String) -> String {
        "UPDATE \(table) SET account_id = ? WHERE id = ?"
    }

    static func values(_ account: AgentAccountRow) -> [SQLValue] {
        [
            .text(account.id),
            .text(account.provider.rawValue),
            .text(account.directory),
            .int(account.isDefault ? 1 : 0),
            .text(account.label),
            .double(account.createdAt.timeIntervalSince1970),
            .text(account.isDefault ? ProfileID.initial : account.profileID),
        ]
    }

    static func account(from row: Row) -> AgentAccountRow? {
        guard let id = row.string("id"),
              let provider = AgentKind(rawValue: row.string("provider") ?? "")
        else { return nil }
        return AgentAccountRow(
            id: AgentAccountID(id),
            provider: provider,
            directory: row.string("directory") ?? "",
            isDefault: row.bool("is_default"),
            label: row.string("label") ?? "",
            createdAt: row.date("created_at") ?? Date(timeIntervalSince1970: 0),
            profileID: ProfileID(row.string(profileColumn) ?? ProfileID.initial.rawValue)
        )
    }
}
