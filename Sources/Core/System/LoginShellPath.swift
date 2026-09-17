import Foundation
import Synchronization

public enum LoginShellPath {
    public static let timeout: Duration = .seconds(5)

    public static let switchVariable = "UD_LOGIN_SHELL_PATH"

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
            shell, ["-i", "-l", "-c", "/usr/bin/env -0"], env: overlay, timeout: timeout
        )
        guard let result, result.status == 0 else { return [] }
        return directories(inEnvironmentDump: result.stdout)
    }

    static func directories(inEnvironmentDump data: Data) -> [String] {
        for (index, record) in data.split(separator: 0, omittingEmptySubsequences: false).enumerated() {
            let text = String(decoding: record, as: UTF8.self)
            let candidate = index == 0 ? (text.components(separatedBy: "\n").last ?? text) : text
            guard candidate.hasPrefix("PATH=") else { continue }
            return unique(String(candidate.dropFirst("PATH=".count)).components(separatedBy: ":"))
                .filter { $0.hasPrefix("/") }
        }
        return []
    }

    static func merge(discovered: [String], inherited: [String], guessed: [String]) -> [String] {
        unique(discovered + inherited + guessed).filter { !$0.isEmpty }
    }

    private static func unique(_ entries: [String]) -> [String] {
        var seen = Set<String>()
        return entries.filter { seen.insert($0).inserted }
    }
}
