import Foundation

enum ProfileColumns {
    static let column = "profile_id"
    static let addColumn = "ALTER TABLE repos ADD COLUMN profile_id TEXT NOT NULL DEFAULT '\(ProfileID.initial.rawValue)';"

    static let createTable = """
        CREATE TABLE IF NOT EXISTS profiles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            folder TEXT NOT NULL UNIQUE,
            colour TEXT NOT NULL,
            symbol TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL
        );
        """

    static let all = "SELECT * FROM profiles ORDER BY sort_order, created_at"
    static let one = "SELECT * FROM profiles WHERE id = ?"
    static let delete = "DELETE FROM profiles WHERE id = ?"
    static let repoCount = "SELECT COUNT(*) AS total FROM repos WHERE profile_id = ?"
    static let update = "UPDATE profiles SET name = ?, colour = ?, symbol = ?, sort_order = ? WHERE id = ?"

    private static let insertion = """
        INTO profiles (id, name, folder, colour, symbol, sort_order, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """

    static let insert = "INSERT " + insertion

    static func migrate(_ db: SQLiteDatabase) throws {
        try db.execute(createTable)
        try db.run("INSERT OR IGNORE " + insertion, values(initial))
        let columns = Set(try db.query("PRAGMA table_info(repos);").compactMap { $0.string("name") })
        guard !columns.isEmpty, !columns.contains(column) else { return }
        try db.execute(addColumn)
    }

    static func values(_ profile: Profile) -> [SQLValue] {
        [
            .text(profile.id), .text(profile.name), .text(profile.folder), .text(profile.colour),
            .text(profile.symbol), .int(Int64(profile.sortOrder)),
            .double(profile.createdAt.timeIntervalSince1970),
        ]
    }

    static func updateValues(_ profile: Profile) -> [SQLValue] {
        [
            .text(profile.name), .text(profile.colour), .text(profile.symbol),
            .int(Int64(profile.sortOrder)), .text(profile.id),
        ]
    }

    static func profile(from row: Row) -> Profile {
        Profile(
            id: ProfileID(row.string("id") ?? ""),
            name: row.string("name") ?? "",
            folder: row.string("folder") ?? "",
            colour: row.string("colour") ?? Accent.all[0],
            symbol: row.string("symbol") ?? initial.symbol,
            sortOrder: Int(row.int("sort_order") ?? 0),
            createdAt: row.date("created_at") ?? Date(timeIntervalSince1970: 0)
        )
    }

    private static var initial: Profile {
        Profile(
            id: .initial,
            name: "Unified",
            folder: ProfileID.initial.rawValue,
            colour: Accent.all[0],
            symbol: "square.stack.3d.up"
        )
    }
}
