import Foundation

public enum MergeMethodChoice {
    public static let fallback = GitHub.MergeMethod.merge

    public static let offered = GitHub.MergeMethod.allCases

    public static let appDefaultKey = "defaults.mergeMethod"

    public static func key(repoID: RepoID) -> String {
        "repo.\(repoID).mergeMethod"
    }

    public static func parse(_ stored: String?) -> GitHub.MergeMethod? {
        stored.flatMap(GitHub.MergeMethod.init(rawValue:))
    }

    public static func resolve(project: String?, app: String?) -> GitHub.MergeMethod {
        parse(project) ?? parse(app) ?? fallback
    }

    public static func load(repoID: RepoID, from store: Store) async -> GitHub.MergeMethod {
        resolve(
            project: try? await store.setting(key(repoID: repoID)),
            app: try? await store.setting(appDefaultKey)
        )
    }

    public static func projectChoice(repoID: RepoID, from store: Store) async -> GitHub.MergeMethod? {
        parse(try? await store.setting(key(repoID: repoID)))
    }

    public static func save(_ method: GitHub.MergeMethod?, repoID: RepoID, to store: Store) async {
        try? await store.setSetting(key(repoID: repoID), method?.rawValue)
    }

    public static func appDefault(from store: Store) async -> GitHub.MergeMethod {
        parse(try? await store.setting(appDefaultKey)) ?? fallback
    }

    public static func saveAppDefault(_ method: GitHub.MergeMethod, to store: Store) async {
        try? await store.setSetting(appDefaultKey, method.rawValue)
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
