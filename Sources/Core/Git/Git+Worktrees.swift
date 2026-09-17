import Foundation

extension Git {
    public static func worktrees(of repo: String) async throws -> [WorktreeEntry] {
        WorktreeListing.parse(try await checkRaw(["worktree", "list", "--porcelain", "-z"], in: repo).stdout)
    }

    public static func addWorktree(
        repo: String,
        path: String,
        branch: String,
        base: String,
        branchIsNew: Bool? = nil,
        replacingPrunableWorktreeAt previousPath: String? = nil
    ) async throws {
        guard FileManager.default.fileExists(atPath: repo) else { throw WorkspaceError.projectFolderMissing }
        try validate(branch: branch)
        try validate(ref: base, label: "base branch")
        try validate(ref: path, label: "worktree path")

        let parent = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)

        let exists = if let branchIsNew { !branchIsNew } else { await branchExists(branch, in: repo) }
        if exists {
            if let previousPath {
                let holders = try await worktrees(of: repo).filter { $0.branch == branch }
                if holders.count == 1, let holder = holders.first,
                   URL(fileURLWithPath: holder.path).resolvingSymlinksInPath()
                    == URL(fileURLWithPath: previousPath).resolvingSymlinksInPath(),
                   holder.isPrunable, !holder.isLocked {
                    try await check(["worktree", "prune"], in: repo)
                }
            }
            try await check(["worktree", "add", "--", path, branch], in: repo)
        } else {
            try await check(["worktree", "add", "-b", branch, "--", path, base], in: repo)
        }
    }

    public static func removeWorktree(repo: String, path: String, force: Bool = false) async throws {
        try validate(ref: path, label: "worktree path")

        var result = try await run(["worktree", "remove", "--", path], in: repo)
        if !result.ok, force {
            result = try await run(["worktree", "remove", "--force", "--", path], in: repo)
        }

        guard !result.ok else { return }

        try await run(["worktree", "prune"], in: repo)
        if FileManager.default.fileExists(atPath: path) {
            throw error(["worktree", "remove", path], result.status, result.stderr, result.stdout)
        }
    }

    public static func deleteBranch(_ branch: String, in repo: String, force: Bool = false) async throws {
        try validate(branch: branch)
        try await check(["branch", force ? "-D" : "-d", "--", branch], in: repo)
    }
}
