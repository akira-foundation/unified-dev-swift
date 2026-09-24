import Foundation

public enum ReproduciblePaths {
    public static let directories: Set<String> = [
        ".unifieddev",
        "node_modules", "bower_components", "jspm_packages", ".pnpm", ".pnpm-store", ".yarn",
        "vendor", "Pods", "Carthage", ".venv", "venv", "virtualenv", ".tox", ".bundle",
        ".cargo", ".gradle", ".m2", ".stack-work", ".pub-cache", ".dart_tool", "_build",
        "dist", "build", ".build", "target", ".next", ".nuxt", ".output", ".svelte-kit",
        ".astro", ".docusaurus", ".vercel", ".netlify", "DerivedData", ".swiftpm",
        ".cache", ".turbo", ".parcel-cache", ".vite", "__pycache__", ".pytest_cache",
        ".mypy_cache", ".ruff_cache", ".phpunit.cache", ".sass-cache", ".nyc_output",
        ".terraform", ".serverless", "coverage",
    ]

    public static let files: Set<String> = [
        ".DS_Store", "Thumbs.db", ".eslintcache", ".phpunit.result.cache",
    ]

    public static let suffixes = [".pyc", ".pyo", ".class"]

    public static func canBeRebuilt(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard let last = components.last.map(String.init) else { return false }

        if components.contains(where: { directories.contains(String($0)) }) { return true }
        if files.contains(last) { return true }
        return suffixes.contains { last.hasSuffix($0) }
    }
}

public struct WorkspaceSafetyReport: Sendable, Hashable {
    public var hasUncommittedChanges: Bool
    public var untrackedFiles: [String]
    public var unpushedCommits: Int
    public var isBranchMerged: Bool
    public var modifiedIgnoredFiles: [String]
    public var detachedCommits: Int

    public var preservedFolderPath: String?

    public init(
        hasUncommittedChanges: Bool = false,
        untrackedFiles: [String] = [],
        unpushedCommits: Int = 0,
        isBranchMerged: Bool = false,
        modifiedIgnoredFiles: [String] = [],
        detachedCommits: Int = 0
    ) {
        self.hasUncommittedChanges = hasUncommittedChanges
        self.untrackedFiles = untrackedFiles
        self.unpushedCommits = unpushedCommits
        self.isBranchMerged = isBranchMerged
        self.modifiedIgnoredFiles = modifiedIgnoredFiles
        self.detachedCommits = detachedCommits
    }

    public var isSafeToDiscard: Bool {
        isSafeToDiscard(deletingBranch: true)
    }

    public func isSafeToDiscard(deletingBranch: Bool, isPullRequestMerged: Bool = false) -> Bool {
        let workingCopyIsClean = !hasUncommittedChanges
            && untrackedFiles.isEmpty
            && modifiedIgnoredFiles.isEmpty
            && detachedCommits == 0

        guard workingCopyIsClean else { return false }
        guard deletingBranch else { return true }
        return unpushedCommits == 0 || isBranchMerged || isPullRequestMerged
    }

    public var losses: [String] {
        losses(deletingBranch: true)
    }

    public func losses(deletingBranch: Bool, isPullRequestMerged: Bool = false) -> [String] {
        irreversibleLosses(deletingBranch: deletingBranch, isPullRequestMerged: isPullRequestMerged)
            + ignoredFileNotes
    }

    public func irreversibleLosses(
        deletingBranch: Bool, isPullRequestMerged: Bool = false
    ) -> [String] {
        var losses: [String] = []
        if hasUncommittedChanges {
            losses.append("uncommitted changes to tracked files")
        }
        if !untrackedFiles.isEmpty {
            let sample = untrackedFiles.prefix(5).joined(separator: ", ")
            let rest = untrackedFiles.count > 5 ? ", and \(untrackedFiles.count - 5) more" : ""
            losses.append("\(Self.count(untrackedFiles.count, "untracked file")): \(sample)\(rest)")
        }
        if deletingBranch, unpushedCommits > 0, !isBranchMerged, !isPullRequestMerged {
            losses.append(
                "\(Self.count(unpushedCommits, "commit")) that "
                + "\(unpushedCommits == 1 ? "exists" : "exist") on no other branch, tag or remote"
            )
        }
        if detachedCommits > 0 {
            losses.append(
                "\(Self.count(detachedCommits, "commit")) made on a detached HEAD, "
                + "held by no branch"
            )
        }
        return losses
    }

    public var ignoredFileNotes: [String] {
        guard !modifiedIgnoredFiles.isEmpty else { return [] }

        let sample = modifiedIgnoredFiles.prefix(5).joined(separator: ", ")
        let rest = modifiedIgnoredFiles.count > 5
            ? ", and \(modifiedIgnoredFiles.count - 5) more"
            : ""
        let folders = modifiedIgnoredFiles.contains { $0.hasSuffix("/") }
        let one = modifiedIgnoredFiles.count == 1
        let noun = switch (one, folders) {
        case (true, true): "ignored folder"
        case (true, false): "ignored file"
        case (false, true): "ignored files and folders"
        case (false, false): "ignored files"
        }
        return [
            "\(modifiedIgnoredFiles.count) \(noun) that \(one ? "differs" : "differ") "
            + "from the main checkout: \(sample)\(rest)"
        ]
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }
}

extension Git {
    public static func safetyReport(
        worktree: String,
        branch: String,
        base: String,
        repo: String
    ) async throws -> WorkspaceSafetyReport {
        try validate(branch: branch)

        var report = WorkspaceSafetyReport()

        var isDetached = false
        if FileManager.default.fileExists(atPath: worktree) {
            guard await isRepository(worktree) else {
                throw ShellError(
                    command: "git status",
                    status: 128,
                    stderr: "\(worktree) is not a git worktree, so what is in it cannot be checked"
                )
            }
            let status = try await checkRaw(["status", "--porcelain", "-z"], in: worktree)
            (report.hasUncommittedChanges, report.untrackedFiles) = parseStatus(status.stdout)
            report.modifiedIgnoredFiles = try await divergentIgnoredFiles(worktree: worktree, repo: repo)
            isDetached = try await isDetachedHead(worktree: worktree)
        }

        let branchIsThere = await branchExists(branch, in: repo)
        guard isDetached || branchIsThere else { return report }

        let refs = try await allRefs(in: repo)

        if isDetached {
            report.detachedCommits = try await detachedCommitCount(worktree: worktree, excluding: refs)
        }
        guard branchIsThere else { return report }

        let negated = refs
            .filter { $0 != "refs/heads/\(branch)" }
            .map { "^\($0)" }
            .joined(separator: "\n")
        let unique = try await check(
            ["rev-list", "--count", "--stdin", "refs/heads/\(branch)"],
            in: repo,
            stdin: negated.isEmpty ? "\n" : negated + "\n"
        )
        report.unpushedCommits = Int(unique.trimmed) ?? 0

        if base != branch, (try? validate(ref: base, label: "base branch")) != nil {
            let merged = try await run(
                ["merge-base", "--is-ancestor", "refs/heads/\(branch)", base], in: repo
            )
            report.isBranchMerged = merged.ok
        }

        return report
    }

    static func parseStatus(_ data: Data) -> (dirty: Bool, untracked: [String]) {
        var dirty = false
        var untracked: [String] = []
        var records = nulRecords(data)[...]

        while let record = records.popFirst() {
            guard record.count > 3 else { continue }
            let code = String(decoding: record.prefix(2), as: UTF8.self)
            let path = String(decoding: record.dropFirst(3), as: UTF8.self)
            if code == "??" {
                untracked.append(path)
            } else {
                dirty = true
                if code.contains("R") || code.contains("C") { _ = records.popFirst() }
            }
        }
        return (dirty, untracked)
    }

    static func divergentIgnoredFiles(worktree: String, repo: String) async throws -> [String] {
        let ignored = try await checkRaw(
            ["ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z"],
            in: worktree
        )

        var paths: [String] = []
        for record in nulRecords(ignored.stdout) {
            let path = String(decoding: record, as: UTF8.self)
            guard !path.isEmpty, !ReproduciblePaths.canBeRebuilt(path) else { continue }
            paths.append(path)
        }

        let directories = paths.filter { $0.hasSuffix("/") }
        let covering = paths.filter { path in
            !directories.contains { $0 != path && path.hasPrefix($0) }
        }

        var divergent: [String] = []
        for path in covering {
            let here = (worktree as NSString).appendingPathComponent(path)
            let there = (repo as NSString).appendingPathComponent(path)
            let differs = path.hasSuffix("/")
                ? directoryDiffers(here, there)
                : fileDiffers(here, there)
            if differs { divergent.append(path) }
        }
        return divergent.sorted()
    }

    static func fileDiffers(_ here: String, _ there: String) -> Bool {
        let manager = FileManager.default
        guard manager.fileExists(atPath: here) else { return false }
        guard manager.fileExists(atPath: there) else { return true }

        let mySize = (try? manager.attributesOfItem(atPath: here)[.size] as? Int)
        let theirSize = (try? manager.attributesOfItem(atPath: there)[.size] as? Int)
        if let mySize, let theirSize, mySize != theirSize { return true }

        guard let mine = manager.contents(atPath: here) else { return true }
        guard let theirs = manager.contents(atPath: there) else { return true }
        return mine != theirs
    }

    static func directoryDiffers(_ here: String, _ there: String, limit: Int = 2_000) -> Bool {
        let manager = FileManager.default
        guard manager.fileExists(atPath: here) else { return false }
        guard manager.fileExists(atPath: there) else { return true }

        guard let walk = manager.enumerator(atPath: here) else { return true }
        var seen = 0
        for case let relative as String in walk {
            var isDirectory: ObjCBool = false
            let file = (here as NSString).appendingPathComponent(relative)
            guard manager.fileExists(atPath: file, isDirectory: &isDirectory), !isDirectory.boolValue
            else { continue }

            seen += 1
            if seen > limit { return true }
            if fileDiffers(file, (there as NSString).appendingPathComponent(relative)) { return true }
        }
        return false
    }

    static func isDetachedHead(worktree: String) async throws -> Bool {
        let head = try await run(["symbolic-ref", "--quiet", "HEAD"], in: worktree)
        return !head.ok
    }

    static func allRefs(in repo: String) async throws -> [String] {
        try await check(
            ["for-each-ref", "--format=%(refname)", "refs/heads", "refs/remotes", "refs/tags"],
            in: repo
        ).lines
    }

    static func detachedCommitCount(worktree: String, excluding refs: [String]) async throws -> Int {
        let negated = refs.map { "^\($0)" }.joined(separator: "\n")
        let unique = try await run(
            ["rev-list", "--count", "--stdin", "HEAD"],
            in: worktree,
            stdin: negated.isEmpty ? "\n" : negated + "\n"
        )
        guard unique.ok else { return 0 }
        return Int(unique.trimmed) ?? 0
    }
}
