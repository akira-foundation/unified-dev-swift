import Foundation

public struct WorkspaceSourceCatalogue: Sendable {
    public let primaryRemote: String?
    public let baseBranches: [String]
    public let holders: [String: BranchHolder]
    public let localBranches: Set<String>
    public private(set) var offering: WorkspaceSourceOffering

    private let listing: WorkspaceBranchListing
    private let defaultBranch: String
    private let remoteBases: Set<String>

    public init(
        listing: WorkspaceBranchListing,
        defaultBranch: String,
        projectPath: String,
        workspaceNames: [String: String],
        pullRequests: [PullRequestListing] = []
    ) {
        let remoteBases = listing.primaryRemoteBranches
        let holders = BranchHolder.byBranch(
            worktrees: listing.worktrees, projectPath: projectPath, workspaceNames: workspaceNames
        )
        self.listing = listing
        self.defaultBranch = defaultBranch
        self.remoteBases = Set(remoteBases)
        self.primaryRemote = listing.primaryRemote
        self.baseBranches = WorkspaceStartContext.baseBranchOptions(
            local: listing.local, remote: remoteBases, defaultBranch: defaultBranch
        )
        self.holders = holders
        self.localBranches = Set(listing.local)
        self.offering = Self.offering(
            listing: listing, defaultBranch: defaultBranch, holders: holders,
            pullRequests: pullRequests, bases: self.baseBranches
        )
    }

    public var offersPullRequests: Bool { primaryRemote != nil }

    public func remote(of base: String) -> String? {
        remoteBases.contains(base) ? primaryRemote : nil
    }

    public func with(pullRequests: [PullRequestListing]) -> WorkspaceSourceCatalogue {
        var updated = self
        updated.offering = Self.offering(
            listing: listing, defaultBranch: defaultBranch, holders: holders,
            pullRequests: pullRequests, bases: baseBranches
        )
        return updated
    }

    public static func load(repo: Repo, workspaces: [Workspace]) async -> WorkspaceSourceCatalogue {
        WorkspaceSourceCatalogue(
            listing: await WorkspaceBranchListing.read(repoPath: repo.path),
            defaultBranch: repo.defaultBranch,
            projectPath: repo.path,
            workspaceNames: BranchHolder.names(of: workspaces, in: repo.id)
        )
    }

    private static func offering(
        listing: WorkspaceBranchListing,
        defaultBranch: String,
        holders: [String: BranchHolder],
        pullRequests: [PullRequestListing],
        bases: [String]
    ) -> WorkspaceSourceOffering {
        WorkspaceSourceOffering(
            pullRequests: pullRequests,
            branches: WorkspaceCheckoutPlan.offeredBranches(
                local: listing.local,
                remote: listing.remote,
                defaultBranch: defaultBranch,
                inUse: holders,
                pullRequestHeads: WorkspaceCheckoutPlan.heads(of: pullRequests),
                remoteNames: listing.remoteNames
            ),
            baseBranches: bases
        )
    }
}
