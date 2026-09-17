import Foundation

public extension Git {
    static func addDetachedWorktree(repo: String, path: String, at revision: String = "HEAD") async throws {
        try validate(ref: revision, label: "revision")
        try validate(ref: path, label: "worktree path")

        let parent = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
        try await check(["worktree", "add", "--detach", "--", path, revision], in: repo)
    }

    static func addTrackingWorktree(
        repo: String, path: String, branch: String, remote: String? = nil
    ) async throws {
        try validate(branch: branch)
        try validate(ref: path, label: "worktree path")
        let destination: String?
        if let remote { destination = remote } else {
            destination = try await repositoryContext(in: repo, branch: branch).publishRemote
        }
        guard let remote = destination else {
            throw error(["worktree", "add"], 1, "No remote is configured for \(branch).", "")
        }
        try validate(ref: remote, label: "remote")

        let parent = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
        try await check(
            ["worktree", "add", "--track", "-b", branch, "--", path, "\(remote)/\(branch)"],
            in: repo
        )
    }

    static func remoteBranches(of repo: String) async throws -> [String] {
        try await check(
            ["for-each-ref", "--format=%(refname:short)", "refs/remotes"], in: repo
        ).lines
    }
}
