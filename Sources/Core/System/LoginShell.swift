import Foundation

public enum LoginShell {
    public static let fallback = "/bin/zsh"

    public static func path(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String {
        guard let named = environment["SHELL"], !named.isEmpty, isExecutable(named) else {
            return fallback
        }
        return named
    }

    public static func argumentZero(for path: String) -> String {
        "-" + (path as NSString).lastPathComponent
    }
}
