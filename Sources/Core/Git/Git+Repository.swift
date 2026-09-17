import Foundation

public extension Git {
    @discardableResult
    static func initRepository(at path: String) async throws -> String {
        let configured = try? await run(["config", "--get", "init.defaultBranch"], in: path)
        let preference = (configured?.ok ?? false) ? configured?.trimmed ?? "" : ""
        let arguments = preference.isEmpty ? ["init", "-b", "main"] : ["init"]
        try await check(arguments, in: path)
        return try await check(["symbolic-ref", "--short", "HEAD"], in: path).trimmed
    }

    static func hasCommits(in path: String) async -> Bool {
        let result = try? await run(["rev-parse", "--verify", "--quiet", "HEAD"], in: path)
        return result?.ok ?? false
    }

    static func commitIdentity(in path: String) async -> (name: String?, email: String?) {
        guard let result = try? await run(
            ["config", "--get-regexp", "^user\\.(name|email)$"], in: path
        ), result.ok else { return (nil, nil) }

        var values: [String: String] = [:]
        for line in result.lines {
            guard let space = line.firstIndex(of: " ") else { continue }
            let value = line[line.index(after: space)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            values[String(line[..<space])] = value
        }
        return (values["user.name"], values["user.email"])
    }

    static func enclosingRepositoryRoot(of path: String) -> String? {
        let manager = FileManager.default
        var current = URL(fileURLWithPath: FolderPath.normalize(path)).deletingLastPathComponent()
        while current.path != "/" && !current.path.isEmpty {
            if manager.fileExists(atPath: current.appendingPathComponent(".git").path) {
                return current.path
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return nil
    }

    static func isIgnored(_ relativePath: String, in repo: String) async -> Bool {
        let result = try? await run(["check-ignore", "--quiet", "--", relativePath], in: repo)
        return result?.ok ?? false
    }

    static func ignoredPaths(among paths: [String], in repo: String) async -> Set<String> {
        guard !paths.isEmpty else { return [] }
        guard let result = try? await run(
            ["check-ignore", "-z", "--stdin"],
            in: repo,
            stdin: paths.joined(separator: "\0") + "\0"
        ), result.status == 0 || result.status == 1 else { return [] }

        return Set(result.stdout.split(separator: "\0").map(String.init))
    }

    static func stageAll(in repo: String) async throws {
        try await check(["add", "--all", "--", "."], in: repo)
    }

    static func stagedPaths(in repo: String) async throws -> [String] {
        let output = try await checkRaw(["diff", "--cached", "--name-only", "-z", "--"], in: repo)
        return String(decoding: output.stdout, as: UTF8.self)
            .split(separator: "\0")
            .map(String.init)
    }

    static func unstage(_ paths: [String], in repo: String) async throws {
        guard !paths.isEmpty else { return }
        try await check(["rm", "--cached", "--quiet", "-r", "--"] + paths, in: repo)
    }

    static func commit(
        message: String, in repo: String, allowEmpty: Bool
    ) async throws -> Bool {
        var arguments = ["commit", "--message", message]
        if allowEmpty { arguments.append("--allow-empty") }

        let result = try await run(arguments, in: repo)
        if result.ok { return false }

        let output = result.stderr + result.stdout
        guard indicatesSigningFailure(output) else {
            throw error(arguments, result.status, result.stderr, result.stdout)
        }

        try await check(["-c", "commit.gpgsign=false"] + arguments, in: repo)
        return true
    }

    static func indicatesSigningFailure(_ output: String) -> Bool {
        let lowered = output.lowercased()
        return lowered.contains("gpg failed to sign")
            || lowered.contains("failed to write commit object")
            || lowered.contains("failed to fill whole buffer")
            || lowered.contains("signing failed")
            || lowered.contains("no secret key")
    }

    static func addRemote(_ name: String, url: String, in repo: String) async throws {
        try await check(["remote", "add", "--", name, url], in: repo)
    }

    static func remoteURL(_ name: String, in repo: String) async -> String? {
        guard let result = try? await run(["remote", "get-url", "--", name], in: repo),
              result.ok else { return nil }
        let trimmed = result.trimmed
        return trimmed.isEmpty ? nil : trimmed
    }
}
