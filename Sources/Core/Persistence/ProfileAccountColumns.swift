import Foundation

enum ProfileAccountColumns {
    static let sourceColumn = "account_source"

    static let owners = "SELECT id, \(AgentAccountColumns.profileColumn) AS profile_id FROM agent_accounts"
    static let sources = "SELECT id, \(sourceColumn) AS source FROM profiles"
    static let setOwner = "UPDATE agent_accounts SET \(AgentAccountColumns.profileColumn) = ? WHERE id = ?"
    static let setSource = "UPDATE profiles SET \(sourceColumn) = ? WHERE id = ?"
    static let returnToInitial = """
        UPDATE agent_accounts SET \(AgentAccountColumns.profileColumn) = '\(ProfileID.initial.rawValue)'
        WHERE \(AgentAccountColumns.profileColumn) = ?
        """

    static func repair(_ db: SQLiteDatabase) throws {
        let columns = Set(try db.query("PRAGMA table_info(profiles);").compactMap { $0.string("name") })
        guard !columns.isEmpty else { return }
        try db.execute(AgentAccountChoiceColumns.profiles.createTable)
        guard !columns.contains(sourceColumn) else { return }
        try db.execute(
            "ALTER TABLE profiles ADD COLUMN \(sourceColumn) TEXT NOT NULL DEFAULT '\(ProfileAccountSource.own.rawValue)';"
        )
    }

    static func migrate(_ db: SQLiteDatabase) throws {
        try repair(db)
        let book = try AgentAccountChoiceColumns.book { try db.query($0) }
        var owners: [AgentAccountID: ProfileID] = [:]
        for row in try db.query("SELECT id FROM agent_accounts WHERE is_default = 0") {
            guard let id = row.string("id").map(AgentAccountID.init) else { continue }
            let owner = ProfileAccounts.migratedOwner(
                of: id, repoChoices: book.repos, repoProfiles: book.repoProfiles
            )
            owners[id] = owner
            try db.run(setOwner, [.text(owner), .text(id)])
        }
        for row in try db.query("SELECT id FROM profiles") {
            guard let id = row.string("id").map(ProfileID.init) else { continue }
            let source = ProfileAccounts.migratedSource(of: id, owners: owners)
            try db.run(setSource, [.text(source.rawValue), .text(id)])
        }
    }

    static func accounts(reading query: (String) throws -> [Row]) throws -> ProfileAccounts {
        var owners: [AgentAccountID: ProfileID] = [:]
        for row in try query(Self.owners) {
            guard let id = row.string("id"), let owner = row.string("profile_id") else { continue }
            owners[AgentAccountID(id)] = ProfileID(owner)
        }
        var sources: [ProfileID: ProfileAccountSource] = [:]
        for row in try query(Self.sources) {
            guard let id = row.string("id"), let source = ProfileAccountSource(rawValue: row.string("source") ?? "")
            else { continue }
            sources[ProfileID(id)] = source
        }
        return ProfileAccounts(owners: owners, sources: sources)
    }
}
