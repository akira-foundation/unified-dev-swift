import Foundation

public enum PreviewLaunch {
    public static let argument = "--scenario"

    public static func scenarioPath(arguments: [String] = CommandLine.arguments) -> String? {
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else {
            return nil
        }
        let path = arguments[index + 1]
        return path.isEmpty || path.hasPrefix("-") ? nil : path
    }

    public static func scenario(at path: String) throws -> PreviewScenario {
        guard path.hasPrefix("/") else {
            throw PreviewScenarioError.unreadable(
                "\(path) is relative, and an app opened with `open` starts in /. Give the scenario as an absolute path"
            )
        }
        return try PreviewScenario.read(path: path)
    }

    public static func root(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        info: [String: Any]? = Bundle.main.infoDictionary
    ) throws -> String {
        guard PreviewIdentity.isPreview(bundleIdentifier: bundleIdentifier),
              let root = LaunchOverride.value(PreviewIdentity.rootOverride, environment: environment, info: info),
              let database = LaunchOverride.value(Store.databaseOverride, environment: environment, info: info),
              let workspaces = LaunchOverride.value(WorkspacesRoot.override, environment: environment, info: info),
              root.hasPrefix("/"),
              FolderPath.isInside(database, of: root),
              FolderPath.isInside(workspaces, of: root) else {
            throw PreviewScenarioError.notAPreview
        }
        return root
    }
}
