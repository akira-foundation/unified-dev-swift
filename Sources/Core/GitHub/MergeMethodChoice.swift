import Foundation

public enum MergeMethodChoice {
    public static let fallback = GitHub.MergeMethod.squash

    public static let offered = GitHub.MergeMethod.allCases

    public static func key(repoID: RepoID) -> String {
        "repo.\(repoID).mergeMethod"
    }

    public static func resolve(_ stored: String?) -> GitHub.MergeMethod {
        guard let stored, let method = GitHub.MergeMethod(rawValue: stored) else { return fallback }
        return method
    }

    public static func load(repoID: RepoID, from store: Store) async -> GitHub.MergeMethod {
        resolve(try? await store.setting(key(repoID: repoID)))
    }

    public static func save(_ method: GitHub.MergeMethod, repoID: RepoID, to store: Store) async {
        try? await store.setSetting(key(repoID: repoID), method.rawValue)
    }
}

public extension GitHub.MergeMethod {
    var buttonLabel: String {
        switch self {
        case .merge: "Merge"
        case .squash: "Squash and merge"
        case .rebase: "Rebase and merge"
        }
    }
}
