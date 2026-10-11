import Foundation

public enum TranscriptHome {
    public static let override = "UD_TRANSCRIPT_HOME"

    public static func overrideValue(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        info: [String: Any]? = Bundle.main.infoDictionary
    ) -> String? {
        guard PreviewIdentity.isPreview(bundleIdentifier: bundleIdentifier) else { return nil }
        return LaunchOverride.value(override, environment: environment, info: info)
    }

    public static func resolve(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        overriddenBy value: String? = overrideValue()
    ) -> URL {
        guard let value else { return home }
        return URL(filePath: value, directoryHint: .isDirectory)
    }

    public static func environment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        overriddenBy value: String? = overrideValue()
    ) -> [String: String] {
        value == nil ? environment : [:]
    }

    public static func seedable(
        overriddenBy value: String? = overrideValue(),
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        let seeded = URL(filePath: value, directoryHint: .isDirectory)
        let theirs = [
            TranscriptSources.claudeHome(home: home, environment: environment),
            TranscriptSources.codexHome(home: home, environment: environment),
        ]
        guard !isSame(seeded, as: home),
              !theirs.contains(where: { isInside(seeded, of: $0) })
        else { return nil }
        return seeded
    }

    static func isSame(_ url: URL, as directory: URL) -> Bool {
        url.standardizedFileURL.path == directory.standardizedFileURL.path
    }

    static func isInside(_ url: URL, of directory: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let top = directory.standardizedFileURL.path
        return path == top || path.hasPrefix(top.hasSuffix("/") ? top : top + "/")
    }
}
