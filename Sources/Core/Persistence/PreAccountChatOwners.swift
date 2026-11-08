import Foundation

enum PreAccountChatOwners {
    static func record(_ db: SQLiteDatabase, predatingAccounts: Bool, defaults: [AgentAccountHome]? = nil) throws {
        guard predatingAccounts else { return }
        for home in defaults ?? SpendAccounts.defaultHomes() where home.isDefault {
            let provider = SQLValue.text(home.provider.rawValue)
            guard try !db.query(unowned, [provider]).isEmpty else { continue }
            try db.run(AgentAccountColumns.insertIfMissing, AgentAccountColumns.values(AgentAccountRow(
                id: home.id, provider: home.provider, directory: home.directory.path, isDefault: true
            )))
            try db.run(recordSessions, [.text(home.id), provider])
            try db.run(recordSegments, [.text(home.id), provider])
        }
    }

    private static let unowned = """
        SELECT 1 FROM sessions
        WHERE agent_kind = ? AND account_id IS NULL AND COALESCE(agent_session_id, '') <> '' LIMIT 1
        """

    private static let recordSessions = """
        UPDATE sessions SET account_id = ?1
        WHERE agent_kind = ?2 AND account_id IS NULL AND COALESCE(agent_session_id, '') <> ''
        """

    private static let recordSegments = """
        UPDATE session_segments SET account_id = ?1
        WHERE agent_kind = ?2 AND account_id IS NULL AND COALESCE(agent_session_id, '') <> ''
        """
}
