import Foundation

public enum RepositoryOwnSetup: Sendable, Equatable {
    case hook(String)
    case setting(String)
    case unreadable(String)

    static let plainSettings: Set<String> = [
        "core.repositoryformatversion", "core.filemode", "core.bare", "core.logallrefupdates",
        "core.ignorecase", "core.precomposeunicode", "core.symlinks",
        "init.defaultbranch", "user.name", "user.email",
        "extensions.objectformat", "extensions.worktreeconfig",
    ]

    static let plainNamedSettings: [String: Set<String>] = [
        "remote": ["url", "fetch"],
        "branch": ["remote", "merge"],
    ]

    static func unfamiliarSetting(in listing: String) -> String? {
        for line in listing.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, ["local", "worktree"].contains(parts[0]) else { continue }
            let key = String(parts[1])
            guard !isPlain(key) else { continue }
            return key
        }
        return nil
    }

    static func isPlain(_ key: String) -> Bool {
        if plainSettings.contains(key.lowercased()) { return true }
        guard let firstDot = key.firstIndex(of: "."), let lastDot = key.lastIndex(of: "."), firstDot < lastDot else {
            return false
        }
        let section = key[..<firstDot].lowercased()
        let variable = key[key.index(after: lastDot)...].lowercased()
        return plainNamedSettings[section]?.contains(variable) ?? false
    }

    static let hookNames = [
        "applypatch-msg", "pre-applypatch", "post-applypatch", "pre-commit", "pre-merge-commit",
        "prepare-commit-msg", "commit-msg", "post-commit", "pre-rebase", "post-checkout", "post-merge",
        "pre-push", "pre-receive", "update", "proc-receive", "post-receive", "post-update",
        "reference-transaction", "push-to-checkout", "pre-auto-gc", "post-rewrite", "sendemail-validate",
        "fsmonitor-watchman", "p4-changelist", "p4-prepare-changelist", "p4-post-changelist",
        "p4-pre-submit", "post-index-change",
    ]

    static func hookSetup(in directory: String) -> RepositoryOwnSetup? {
        let manager = FileManager.default
        if let named = hookNames.first(where: { isExecutableHook((directory as NSString).appendingPathComponent($0)) }) {
            return .hook(named)
        }
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: directory, isDirectory: &isDirectory) else { return nil }
        guard isDirectory.boolValue, let names = try? manager.contentsOfDirectory(atPath: directory) else {
            return .unreadable("its hooks folder, \(directory), cannot be listed")
        }
        let listed = names.sorted().first { name in
            !name.hasSuffix(".sample") && isExecutableHook((directory as NSString).appendingPathComponent(name))
        }
        return listed.map(RepositoryOwnSetup.hook)
    }

    private static func isExecutableHook(_ path: String) -> Bool {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        return manager.isExecutableFile(atPath: path)
    }
}

extension Git {
    static func ownSetup(of root: String) async -> RepositoryOwnSetup? {
        do {
            let settings = try await run(["config", "--list", "--show-scope", "--includes", "--name-only"], in: root)
            guard settings.ok else {
                return .unreadable(settings.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if let key = RepositoryOwnSetup.unfamiliarSetting(in: settings.stdout) { return .setting(key) }

            let common = try await check(["rev-parse", "--git-common-dir"], in: root).trimmed
            let gitDirectory = (common as NSString).isAbsolutePath
                ? common : (root as NSString).appendingPathComponent(common)
            return RepositoryOwnSetup.hookSetup(in: (gitDirectory as NSString).appendingPathComponent("hooks"))
        } catch {
            return .unreadable(error.readableMessage)
        }
    }
}
