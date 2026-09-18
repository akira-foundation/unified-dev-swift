import Foundation

public enum WorkspacesRoot {
    public static let preferredName = "unifieddev/workspaces.noindex"

    public static let legacyName = "unifieddev/workspaces"

    public static func resolve(home: URL, exists: (URL) -> Bool) -> URL {
        let preferred = home.appendingPathComponent(preferredName, isDirectory: true)
        if exists(preferred) { return preferred }

        let legacy = home.appendingPathComponent(legacyName, isDirectory: true)
        if exists(legacy) { return legacy }

        return preferred
    }

    public static let override = "UD_WORKSPACES_ROOT"

    public static func overrideValue(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        info: [String: Any]? = Bundle.main.infoDictionary
    ) -> String? {
        guard bundleIdentifier != Store.primaryBundleIdentifier else { return nil }
        return LaunchOverride.value(override, environment: environment, info: info)
    }

    public static func resolve(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        overriddenBy value: String? = overrideValue()
    ) -> URL {
        if let value { return URL(fileURLWithPath: value, isDirectory: true) }
        return resolve(home: home) { url in
            var isDirectory: ObjCBool = false
            let there = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            return there && isDirectory.boolValue
        }
    }

    public static func note(for root: URL) -> String {
        if root.lastPathComponent.hasSuffix(".noindex") {
            return "The name ends .noindex, which is what keeps Spotlight out of the dependencies "
                + "and build folders inside every worktree."
        }
        return "New installations use a folder named .noindex, which keeps Spotlight out of the "
            + "dependencies and build folders inside every worktree. This one keeps the folder it "
            + "already has, because moving a worktree would break the path git and Unified Dev both "
            + "hold for it."
    }
}
