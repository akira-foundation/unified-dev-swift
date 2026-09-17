import Foundation
import Synchronization

public enum LoginShellPath {
    public static let timeout: Duration = .seconds(5)

    public static let switchVariable = "UD_LOGIN_SHELL_PATH"

    static let sentinel = "/usr/bin/printf '\\0'; /usr/bin/env -0"

    private static let probe = Mutex<Task<Void, Never>?>(nil)

    public static func begin() {
        _ = task()
    }

    public static func ready() async {
        await task().value
    }

    private static func task() -> Task<Void, Never> {
        probe.withLock { existing in
            if let existing { return existing }
            let started = Task<Void, Never> {
                Shell.adoptLoginShellPath(await discover())
            }
            existing = started
            return started
        }
    }

    static func discover(
        shell: String = LoginShell.path(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        overlay: [String: String] = [:],
        timeout: Duration = LoginShellPath.timeout
    ) async -> [String] {
        guard environment[switchVariable] != "0" else { return [] }
        let result = try? await Shell.runBytes(
            shell, ["-i", "-l", "-c", sentinel], env: overlay, timeout: timeout
        )
        guard let result, result.status == 0 else { return [] }
        return directories(inEnvironmentDump: result.stdout)
    }

    static func directories(inEnvironmentDump data: Data) -> [String] {
        for record in data.split(separator: 0, omittingEmptySubsequences: false).dropFirst() {
            let text = String(decoding: record, as: UTF8.self)
            guard text.hasPrefix("PATH=") else { continue }
            return String(text.dropFirst("PATH=".count)).components(separatedBy: ":")
        }
        return []
    }

    static func merge(discovered: [String], inherited: [String], guessed: [String]) -> [String] {
        var seen = Set<String>()
        return (discovered + inherited + guessed)
            .filter { $0.hasPrefix("/") }
            .filter { seen.insert($0).inserted }
    }
}
