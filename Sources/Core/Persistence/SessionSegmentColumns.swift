import Foundation

enum SessionSegmentColumns {
    static func migrate(_ db: SQLiteDatabase) throws {
        try db.execute(createTable)
        try db.execute(insertMissing)
    }

    static let createTable = """
        CREATE TABLE IF NOT EXISTS session_segments (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            agent_kind TEXT NOT NULL,
            account_id TEXT REFERENCES agent_accounts(id) ON DELETE SET NULL,
            agent_session_id TEXT,
            model TEXT NOT NULL,
            effort TEXT NOT NULL DEFAULT '',
            cursor_seq INTEGER NOT NULL DEFAULT -1,
            entered_seq INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 0,
            input_tokens INTEGER NOT NULL DEFAULT 0,
            output_tokens INTEGER NOT NULL DEFAULT 0,
            cost_usd REAL NOT NULL DEFAULT 0,
            context_tokens INTEGER NOT NULL DEFAULT 0,
            seed_session_id TEXT REFERENCES sessions(id) ON DELETE SET NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS session_segments_session ON session_segments(session_id);
        CREATE UNIQUE INDEX IF NOT EXISTS session_segments_one_active
            ON session_segments(session_id) WHERE is_active = 1;
        """

    private static let insertMissing = """
        INSERT INTO session_segments
            (id, session_id, agent_kind, account_id, agent_session_id, model, effort,
             cursor_seq, entered_seq, is_active, input_tokens, output_tokens, cost_usd,
             context_tokens, created_at)
        SELECT lower(hex(randomblob(16))), s.id, s.agent_kind, s.account_id, s.agent_session_id,
               s.model, s.effort,
               COALESCE((SELECT MAX(seq) FROM messages m WHERE m.session_id = s.id), -1),
               0, 1, s.input_tokens, s.output_tokens, s.cost_usd, s.context_tokens, s.created_at
        FROM sessions s
        WHERE NOT EXISTS (SELECT 1 FROM session_segments g WHERE g.session_id = s.id)
        """

    static let ensureFirst = insertMissing + " AND s.id = ?"

    static let forSession = "SELECT * FROM session_segments WHERE session_id = ? ORDER BY created_at, rowid"

    static let active = "SELECT * FROM session_segments WHERE session_id = ? AND is_active = 1"

    static let advance = "UPDATE session_segments SET cursor_seq = MAX(cursor_seq, ?) WHERE id = ?"

    static let reset = "UPDATE session_segments SET cursor_seq = -1 WHERE id = ?"

    static let seed = "UPDATE session_segments SET seed_session_id = ? WHERE session_id = ? AND is_active = 1"

    static let forgetHistory = """
        UPDATE session_segments SET agent_session_id = NULL, cursor_seq = -1 WHERE account_id = ?
        """

    static func segment(from row: Row) -> SessionSegment? {
        guard let id = row.string("id"),
              let sessionID = row.string("session_id"),
              let kind = AgentKind(rawValue: row.string("agent_kind") ?? "")
        else { return nil }
        return SessionSegment(
            id: SessionSegmentID(id),
            sessionID: SessionID(sessionID),
            agentKind: kind,
            accountID: row.string("account_id").map(AgentAccountID.init),
            agentSessionID: row.string("agent_session_id"),
            model: row.string("model") ?? "",
            effort: row.string("effort") ?? "",
            cursorSeq: Int(row.int("cursor_seq") ?? -1),
            enteredSeq: Int(row.int("entered_seq") ?? 0),
            isActive: row.bool("is_active"),
            seedSessionID: row.string("seed_session_id").map(SessionID.init)
        )
    }
}
