import Foundation

enum PullRequestSeenOpenColumn {
    static let column = "pull_request_seen_open"
    static let addColumn = "ALTER TABLE workspaces ADD COLUMN pull_request_seen_open INTEGER;"

    static func migrate(_ db: SQLiteDatabase) throws {
        let columns = Set(try db.query("PRAGMA table_info(workspaces);").compactMap { $0.string("name") })
        guard !columns.contains(column) else { return }
        try db.execute(addColumn)
    }
}
