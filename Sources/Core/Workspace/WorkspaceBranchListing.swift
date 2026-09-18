import Foundation

public struct WorkspaceBranchListing: Sendable, Equatable {
    public let local: [String]
    public let remote: [String]
    public let remoteNames: [String]
    public let worktrees: [WorktreeEntry]

    public init(local: [String], remote: [String], remoteNames: [String], worktrees: [WorktreeEntry]) {
        self.local = local
        self.remote = remote
        self.remoteNames = remoteNames
        self.worktrees = worktrees
    }

    public static func read(repoPath: String) async -> WorkspaceBranchListing {
        async let local = Git.branches(of: repoPath)
        async let remote = Git.remoteBranches(of: repoPath)
        async let names = Git.remoteNames(of: repoPath)
        async let worktrees = Git.worktrees(of: repoPath)
        return WorkspaceBranchListing(
            local: (try? await local) ?? [],
            remote: (try? await remote) ?? [],
            remoteNames: (try? await names) ?? [],
            worktrees: (try? await worktrees) ?? []
        )
    }

    var primaryRemote: String? { Git.primaryRemote(of: remoteNames) }

    var primaryRemoteBranches: [String] {
        guard let primaryRemote else { return [] }
        return remote.compactMap { WorkspaceCheckoutPlan.remoteBranchName($0, remote: primaryRemote) }
    }
}
