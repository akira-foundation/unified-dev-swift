import Foundation

public enum WorkspaceRestoreRefusal: Error, CustomStringConvertible, Sendable {
    case branchGone(branch: String)

    public var description: String {
        switch self {
        case .branchGone(let branch):
            "the branch \(branch) no longer exists here or on its configured remote"
        }
    }
}

public enum RestoreSource: Sendable, Equatable {
    case localBranch
    case remoteBranch(ref: String)
    case gone

    public var canRebuild: Bool { self != .gone }

    public static func of(hasLocalBranch: Bool, remoteRef: String?) -> RestoreSource {
        if hasLocalBranch { return .localBranch }
        if let remoteRef, !remoteRef.isEmpty { return .remoteBranch(ref: remoteRef) }
        return .gone
    }

    public func explanation(branch: String, remote: String = Git.remote) -> String {
        switch self {
        case .localBranch:
            """
            The branch \(branch) is still here, so the worktree can be built from it again with \
            every commit in place.
            """
        case .remoteBranch:
            """
            The branch \(branch) is gone from this Mac, but \(remote) still has it, so the \
            worktree can be cut again from there.
            """
        case .gone:
            """
            The branch \(branch) no longer exists here or on \(remote), so there is nothing left \
            to build a worktree from and this workspace cannot be worked in again. Everything it \
            said is still here to read.
            """
        }
    }
}

public enum WorktreePath {
    public static func preferred(branch: String, project: String, under root: URL) -> String {
        let directoryName = branch.replacingOccurrences(of: "/", with: "-")
        return root
            .appendingPathComponent(project, isDirectory: true)
            .appendingPathComponent(directoryName)
            .path
    }

    public static func free(preferred: String, isOccupied: (String) -> Bool) -> String {
        var candidate = preferred
        var suffix = 2
        while isOccupied(candidate) {
            candidate = "\(preferred)-\(suffix)"
            suffix += 1
        }
        return candidate
    }
}

public struct RestoreOutcome: Sendable, Equatable {
    public var workspace: Workspace
    public var source: RestoreSource
    public var relocatedFrom: String?

    public init(workspace: Workspace, source: RestoreSource, relocatedFrom: String? = nil) {
        self.workspace = workspace
        self.source = source
        self.relocatedFrom = relocatedFrom
    }
}

public extension WorkspaceSafetyReport {
    var isRestorableFromBranch: Bool {
        preservedFolderPath == nil
            && !hasUncommittedChanges
            && untrackedFiles.isEmpty
            && modifiedIgnoredFiles.isEmpty
            && detachedCommits == 0
    }
}

public extension WorkspaceManager {
    func canRestore(workspace: Workspace, repo: Repo) async -> Bool {
        guard !FileManager.default.fileExists(atPath: workspace.path) else { return false }
        return await Git.branchExists(workspace.branch, in: repo.path)
    }

    func restoreSource(workspace: Workspace, repo: Repo) async -> RestoreSource {
        if await Git.branchExists(workspace.branch, in: repo.path) { return .localBranch }

        guard let context = try? await Git.repositoryContext(
            in: repo.path, baseBranch: workspace.baseBranch, branch: workspace.branch
        ), let remote = context.publishRemote, let ref = context.publishTrackingRef else { return .gone }
        _ = await Git.fetch(workspace.branch, in: repo.path, remote: remote)
        let remoteRef = await Git.revision(of: ref, in: repo.path) == nil ? nil : ref
        return RestoreSource.of(hasLocalBranch: false, remoteRef: remoteRef)
    }

    @discardableResult
    func restore(workspace: Workspace, repo: Repo) async throws -> RestoreOutcome {
        try await restore(
            workspace: workspace,
            repo: repo,
            from: await restoreSource(workspace: workspace, repo: repo)
        )
    }

    @discardableResult
    func restore(
        workspace: Workspace, repo: Repo, from source: RestoreSource
    ) async throws -> RestoreOutcome {
        let repositoryKey = Git.repositoryPaths(in: repo.path)?.commonDirectory
            ?? URL(fileURLWithPath: repo.path).resolvingSymlinksInPath().standardized.path
        return try await WorktreeCutQueue.shared.cut(in: repositoryKey) {
            try await rebuild(workspace: workspace, repo: repo, from: source)
        }
    }

    private func rebuild(
        workspace: Workspace, repo: Repo, from source: RestoreSource
    ) async throws -> RestoreOutcome {
        guard source.canRebuild else {
            throw WorkspaceRestoreRefusal.branchGone(branch: workspace.branch)
        }

        let path = WorktreePath.free(preferred: workspace.path) {
            FileManager.default.fileExists(atPath: $0)
        }

        let base: String
        if case .remoteBranch(let ref) = source {
            base = ref
        } else {
            base = workspace.baseBranch
        }

        try await Git.addWorktree(
            repo: repo.path, path: path, branch: workspace.branch, base: base,
            replacingPrunableWorktreeAt: workspace.path
        )

        let settings = SettingsLoader.load(repo: repo.path)
        try copyFiles(settings.filesToCopy, from: repo.path, to: path)
        let needsSetup = settings.setupScript != nil || Git.hasSubmodules(in: path)

        let updated = try await store.update(workspaceID: workspace.id) {
            $0.restore(to: path, hasSetupScript: needsSetup)
        }
        guard let restored = updated else { throw WorkspaceError.workspaceGone(workspace.name) }

        await bringProjectBack(repo.id)

        return RestoreOutcome(
            workspace: restored,
            source: source,
            relocatedFrom: path == workspace.path ? nil : workspace.path
        )
    }
}
