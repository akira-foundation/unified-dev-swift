import Foundation

enum OrchestratorColumns {
    static func migrate(_ db: SQLiteDatabase) throws {
        let columns = Set(try db.query("PRAGMA table_info(workspaces);").compactMap { $0.string("name") })
        if !columns.contains("is_orchestrator") {
            try db.execute("ALTER TABLE workspaces ADD COLUMN is_orchestrator INTEGER NOT NULL DEFAULT 0;")
        }
        try db.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS workspaces_one_orchestrator
                ON workspaces(repo_id) WHERE is_orchestrator = 1;
            """)
    }
}
