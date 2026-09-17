import Foundation
import Synchronization

public struct ShellResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public var ok: Bool { status == 0 }

    public var trimmed: String {
        stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var lines: [String] {
        trimmed.isEmpty ? [] : trimmed.components(separatedBy: "\n")
    }
}

public struct ShellError: Error, CustomStringConvertible {
    public let command: String
    public let status: Int32
    public let stderr: String

    public var description: String {
        "`\(command)` exited \(status): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}

public enum Shell {
    public static let extraPaths = ExecutableSearchPath.additionalDirectories()

    private static let spawns = Atomic<Int>(0)

    static func countSpawn() {
        spawns.add(1, ordering: .relaxed)
    }

    public static var spawnCount: Int {
        spawns.load(ordering: .relaxed)
    }

    private static let base: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        let existing = env["PATH"]?.components(separatedBy: ":") ?? []
        var seen = Set<String>()
        let merged = (existing + extraPaths).filter { seen.insert($0).inserted }
        env["PATH"] = merged.joined(separator: ":")
        return env
    }()

    public static func environment(extra: [String: String] = [:]) -> [String: String] {
        guard !extra.isEmpty else { return base }
        var env = base
        for (key, value) in extra { env[key] = value }
        return env
    }

    public static func terminalEnvironment(
        inheriting inherited: [String: String], extra: [String: String] = [:]
    ) -> [String: String] {
        var variables = inherited
        variables.removeValue(forKey: "NO_COLOR")
        variables["TERM"] = "xterm-256color"
        variables["COLORTERM"] = "truecolor"
        variables["TERM_PROGRAM"] = "Unified Dev"
        if variables["LANG"] == nil { variables["LANG"] = "en_US.UTF-8" }
        return variables.merging(extra) { _, requested in requested }
    }

    private static let found = Mutex<[String: String]>([:])

    public static func which(_ name: String) -> String? {
        if name.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        if let remembered = found.withLock({ $0[name] }),
           FileManager.default.isExecutableFile(atPath: remembered) {
            return remembered
        }
        for dir in environment()["PATH"]?.components(separatedBy: ":") ?? [] {
            let candidate = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                found.withLock { $0[name] = candidate }
                return candidate
            }
        }
        return nil
    }

    @discardableResult
    public static func run(
        _ executable: String,
        _ arguments: [String] = [],
        cwd: String? = nil,
        env: [String: String] = [:],
        stdin: String? = nil,
        timeout: Duration? = nil,
        outputLimit: Int = 64 * 1_024 * 1_024
    ) async throws -> ShellResult {
        let result = try await runBytes(
            executable, arguments, cwd: cwd, env: env,
            stdin: stdin.map { Data($0.utf8) }, timeout: timeout, outputLimit: outputLimit
        )
        return ShellResult(
            status: result.status,
            stdout: String(decoding: result.stdout, as: UTF8.self),
            stderr: String(decoding: result.stderr, as: UTF8.self)
        )
    }

    public static func runBytes(
        _ executable: String,
        _ arguments: [String] = [],
        cwd: String? = nil,
        env: [String: String] = [:],
        stdin: Data? = nil,
        timeout: Duration? = nil,
        outputLimit: Int = 64 * 1_024 * 1_024
    ) async throws -> ShellBytes {
        try Task.checkCancellation()
        guard let path = which(executable) else {
            throw ShellError(command: executable, status: 127, stderr: "\(executable) not found on PATH")
        }
        return try await CapturedProcess(
            executable: path, arguments: arguments, cwd: cwd, environment: environment(extra: env),
            input: stdin, timeout: timeout, outputLimit: outputLimit
        ).run()
    }

    @discardableResult
    public static func check(
        _ executable: String,
        _ arguments: [String] = [],
        cwd: String? = nil,
        env: [String: String] = [:],
        timeout: Duration? = nil
    ) async throws -> ShellResult {
        let result = try await run(executable, arguments, cwd: cwd, env: env, timeout: timeout)
        guard result.ok else {
            throw ShellError(
                command: ([executable] + arguments).joined(separator: " "),
                status: result.status,
                stderr: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }
        return result
    }

    @discardableResult
    public static func script(
        _ source: String,
        cwd: String,
        env: [String: String] = [:],
        timeout: Duration? = nil
    ) async throws -> ShellResult {
        try await run("/bin/zsh", ["-c", source], cwd: cwd, env: env, timeout: timeout)
    }
}
