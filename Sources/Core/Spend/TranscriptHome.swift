import Foundation

public enum TranscriptHome {
    public static let override = "UD_TRANSCRIPT_HOME"

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
        guard let value else { return home }
        return URL(filePath: value, directoryHint: .isDirectory)
    }

    public static func seedable(overriddenBy value: String? = overrideValue()) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        return URL(filePath: value, directoryHint: .isDirectory)
    }
}
