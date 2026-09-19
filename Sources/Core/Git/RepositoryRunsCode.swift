import Foundation

public enum RepositoryRunsCode: Sendable, Equatable {
    case hook(String)
    case setting(String)
    case unreadable(String)

    static let settingsPattern = #"^core\.(hookspath|fsmonitor)$"#

    static func repositorySetting(in listing: String) -> String? {
        for line in listing.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, ["local", "worktree"].contains(parts[0]) else { continue }
            let entry = parts[1].split(separator: " ", maxSplits: 1)
            let key = String(entry[0]).lowercased()
            let value = entry.count > 1 ? String(entry[1]).trimmingCharacters(in: .whitespaces).lowercased() : ""
            if key == "core.fsmonitor", ["false", "no", "off", "0"].contains(value) { continue }
            return key
        }
        return nil
    }

    static func executableHook(in directory: String) -> String? {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: directory) else { return nil }
        return names.sorted().first { name in
            guard !name.hasSuffix(".sample") else { return false }
            let path = (directory as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard manager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                return false
            }
            return manager.isExecutableFile(atPath: path)
        }
    }
}

extension Git {
    static func codeItRuns(in root: String) async -> RepositoryRunsCode? {
        do {
            let settings = try await run(
                ["config", "--show-scope", "--includes", "--get-regexp", RepositoryRunsCode.settingsPattern], in: root
            )
            guard settings.ok || settings.status == 1 else {
                return .unreadable(settings.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if let key = RepositoryRunsCode.repositorySetting(in: settings.stdout) { return .setting(key) }

            let common = try await check(["rev-parse", "--git-common-dir"], in: root).trimmed
            let gitDirectory = (common as NSString).isAbsolutePath
                ? common : (root as NSString).appendingPathComponent(common)
            return RepositoryRunsCode.executableHook(in: (gitDirectory as NSString).appendingPathComponent("hooks"))
                .map(RepositoryRunsCode.hook)
        } catch {
            return .unreadable(error.readableMessage)
        }
    }
}
