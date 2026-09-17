import Foundation

public struct WorkspaceStartContext: Sendable {
    public let branches: [String]
    public let remoteBranches: [String]
    public let settings: RepoSettings
    public let isNamingAvailable: Bool

    public static func load(repoPath: String) async -> WorkspaceStartContext {
        async let local = Git.branches(of: repoPath)
        async let remote = Git.remoteBranches(of: repoPath)
        async let names = Git.remoteNames(of: repoPath)
        return WorkspaceStartContext(
            branches: (try? await local) ?? [],
            remoteBranches: primaryRemoteBranches(
                references: (try? await remote) ?? [], remoteNames: (try? await names) ?? []
            ),
            settings: SettingsLoader.load(repo: repoPath),
            isNamingAvailable: WorkspaceNamer.isAvailable
        )
    }

    public static func branchOptions(branches: [String], defaultBranch: String) -> [String] {
        branches.isEmpty ? [defaultBranch] : branches
    }

    static func primaryRemoteBranches(references: [String], remoteNames: [String]) -> [String] {
        guard let primary = remoteNames.contains("origin") ? "origin" : remoteNames.min() else {
            return []
        }
        return references.compactMap { WorkspaceCheckoutPlan.remoteBranchName($0, remote: primary) }
    }

    public static func baseBranchOptions(
        local: [String], remote: [String], defaultBranch: String
    ) -> [String] {
        let names = Set(local + remote).filter { !$0.isEmpty }
        return branchOptions(
            branches: names.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            defaultBranch: defaultBranch
        )
    }

    public static func prefetch(_ target: BaseBranchPrefetch?) async {
        guard let target else { return }
        await BaseBranchFetches.prefetch(base: target.baseBranch, in: target.repoPath)
    }

    public static func resolvedBaseBranch(
        current: String,
        branches: [String],
        defaultBranch: String
    ) -> String {
        if branches.contains(current) { return current }
        if branches.contains(defaultBranch) { return defaultBranch }
        return branches.first ?? defaultBranch
    }
}

public struct WorkspaceCheckoutOptions: Sendable {
    public let pullRequests: [PullRequestListing]
    public let branches: [ExistingBranch]
    public let access: GitHubAccess
    public let failure: String?
    public let holders: [String: BranchHolder]

    public init(
        pullRequests: [PullRequestListing] = [],
        branches: [ExistingBranch] = [],
        access: GitHubAccess = .ready,
        failure: String? = nil,
        holders: [String: BranchHolder] = [:]
    ) {
        self.pullRequests = pullRequests
        self.branches = branches
        self.access = access
        self.failure = failure
        self.holders = holders
    }

    public static func load(
        repoPath: String,
        repoID: RepoID,
        defaultBranch: String,
        workspaces: [Workspace] = []
    ) async -> WorkspaceCheckoutOptions {
        async let localListing = Git.branches(of: repoPath)
        async let remoteListing = Git.remoteBranches(of: repoPath)
        async let worktreeListing = Git.worktrees(of: repoPath)
        async let remoteNamesRead = Git.remoteNames(of: repoPath)
        let local = (try? await localListing) ?? []
        let remote = (try? await remoteListing) ?? []
        let remoteNames = (try? await remoteNamesRead) ?? []
        let branchesInUse = BranchHolder.byBranch(
            worktrees: (try? await worktreeListing) ?? [],
            projectPath: repoPath,
            workspaceNames: BranchHolder.names(of: workspaces, in: repoID)
        )

        func options(
            pullRequests: [PullRequestListing] = [],
            access: GitHubAccess = .ready,
            failure: String? = nil
        ) -> WorkspaceCheckoutOptions {
            WorkspaceCheckoutOptions(
                pullRequests: pullRequests,
                branches: WorkspaceCheckoutPlan.offeredBranches(
                    local: local,
                    remote: remote,
                    defaultBranch: defaultBranch,
                    inUse: branchesInUse,
                    pullRequestHeads: WorkspaceCheckoutPlan.heads(of: pullRequests),
                    remoteNames: remoteNames
                ),
                access: access,
                failure: failure,
                holders: branchesInUse
            )
        }

        let access = await GitHub.access()
        guard access == .ready else { return options(access: access) }

        do {
            return options(pullRequests: try await GitHub.openPullRequests(repoPath: repoPath))
        } catch {
            return options(failure: error.readableMessage)
        }
    }
}
