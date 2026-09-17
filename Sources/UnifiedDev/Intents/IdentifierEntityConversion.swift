import AppIntents
import Core

extension RepoID: EntityIdentifierConvertible {
    public var entityIdentifierString: String { rawValue }

    public static func entityIdentifier(for string: String) -> RepoID? { RepoID(string) }
}

extension WorkspaceID: EntityIdentifierConvertible {
    public var entityIdentifierString: String { rawValue }

    public static func entityIdentifier(for string: String) -> WorkspaceID? { WorkspaceID(string) }
}
