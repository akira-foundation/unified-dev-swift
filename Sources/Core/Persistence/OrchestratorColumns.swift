import Foundation

enum OrchestratorColumns {
    static let column = "is_orchestrator"
    static let addColumn = "ALTER TABLE workspaces ADD COLUMN is_orchestrator INTEGER NOT NULL DEFAULT 0;"
    static let uniqueIndex = """
        CREATE UNIQUE INDEX IF NOT EXISTS workspaces_one_orchestrator
            ON workspaces(repo_id) WHERE is_orchestrator = 1;
        """

    static func migrate(_ db: SQLiteDatabase) throws {
        let columns = Set(try db.query("PRAGMA table_info(workspaces);").compactMap { $0.string("name") })
        if !columns.contains(column) {
            try db.execute(addColumn)
        }
        try db.execute(uniqueIndex)
    }
}
