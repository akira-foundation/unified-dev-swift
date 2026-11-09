import Foundation

enum UndatedArchives {
    static func stamp(_ db: SQLiteDatabase, at moment: Date = Date()) throws {
        _ = try db.run(
            "UPDATE workspaces SET archived_at = ? WHERE state = ? AND archived_at IS NULL",
            [.double(moment.timeIntervalSince1970), .text(WorkspaceState.archived.rawValue)]
        )
    }
}
