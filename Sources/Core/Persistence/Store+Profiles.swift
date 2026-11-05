import Foundation

public enum ProfileDeletionRefused: Error, Equatable {
    case initial
    case hasProjects(count: Int)
}

public enum ProfileMoveRefused: Error, Equatable {
    case unknownProfile
}

extension Store {
    private static let activeProfileKey = "profile.active"

    public func createProfile(name: String, colour: String, symbol: String) throws -> Profile {
        let existing = try profiles()
        let taken = Set(existing.map(\.folder)).union([ProfileID.initial.rawValue])
        let profile = Profile(
            id: .new(),
            name: name,
            folder: ProfileFolder.name(for: name, taken: taken),
            colour: colour,
            symbol: symbol,
            sortOrder: (existing.map(\.sortOrder).max() ?? 0) + 1
        )
        try insertProfileRow(profile)
        return profile
    }

    @discardableResult
    public func update(
        profileID: ProfileID,
        _ change: @Sendable (inout Profile) -> Void
    ) throws -> Profile? {
        guard let stored = try profile(id: profileID) else { return nil }
        var changed = stored
        change(&changed)
        let row = Profile(
            id: stored.id,
            name: changed.name,
            folder: stored.folder,
            colour: changed.colour,
            symbol: changed.symbol,
            sortOrder: changed.sortOrder,
            createdAt: stored.createdAt
        )
        try writeProfileRow(row)
        return row
    }

    @discardableResult
    public func move(repoID: RepoID, to profile: ProfileID) throws -> Repo? {
        guard try self.profile(id: profile) != nil else { throw ProfileMoveRefused.unknownProfile }
        return try update(repoID: repoID) { $0.profileID = profile }
    }

    public func deleteProfile(id: ProfileID) throws {
        guard id != .initial else { throw ProfileDeletionRefused.initial }
        let projects = try projectCount(profileID: id)
        guard projects == 0 else { throw ProfileDeletionRefused.hasProjects(count: projects) }
        try removeProfileRow(id: id)
    }

    public func activeProfileID() throws -> ProfileID {
        guard let value = try setting(Self.activeProfileKey), !value.isEmpty else { return .initial }
        return try profile(id: ProfileID(value))?.id ?? .initial
    }

    public func setActiveProfile(_ id: ProfileID) throws {
        try setSetting(Self.activeProfileKey, id.rawValue)
    }
}
