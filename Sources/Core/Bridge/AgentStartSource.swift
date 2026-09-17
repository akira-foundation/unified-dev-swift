import Foundation

public enum AgentStartSource: Sendable, Hashable {
    case newBranch(from: String?)
    case existingBranch(ExistingBranch)
    case pullRequest(PullRequestListing)

    public var tab: WorkspaceSourceTab {
        switch self {
        case .newBranch: .newBranch
        case .existingBranch, .pullRequest: .existingBranch
        }
    }

    public var baseBranch: String? {
        switch self {
        case .newBranch(let ref): ref
        case .existingBranch, .pullRequest: nil
        }
    }

    public var checkout: WorkspaceCheckout? {
        switch self {
        case .newBranch: nil
        case .existingBranch(let branch): .branch(branch)
        case .pullRequest(let request): .pullRequest(request)
        }
    }

    public var namedBranch: String? {
        switch self {
        case .newBranch(let ref): ref
        case .existingBranch(let branch): branch.name
        case .pullRequest(let request): request.headRefName
        }
    }

    var digestMaterial: [String] {
        switch self {
        case .newBranch(let ref): [ref ?? ""]
        case .existingBranch(let branch): ["", "on\u{0}" + branch.name]
        case .pullRequest(let request): ["", "pr\u{0}" + String(request.number)]
        }
    }
}

public enum AgentStartRequest: Sendable, Equatable {
    case newBranch(from: String?)
    case existingBranch(String)
    case pullRequest(String)
    case refused(String)

    public static func read(
        baseBranch: String?, existingBranch: String?, pullRequest: String? = nil
    ) -> AgentStartRequest {
        let named = [baseBranch, existingBranch, pullRequest].compactMap { $0 }
        guard named.count <= 1 else {
            let arguments = [
                baseBranch.map { "base_branch '\($0)'" },
                existingBranch.map { "existing_branch '\($0)'" },
                pullRequest.map { "pull_request '\($0)'" },
            ].compactMap { $0 }.joined(separator: ", ")
            return .refused(
                "workspace_start takes only one source, and this call named \(arguments). Ask "
                    + "again with only base_branch, existing_branch or pull_request."
            )
        }

        switch (baseBranch, existingBranch, pullRequest) {
        case let (_, _, request?):
            return .pullRequest(request)
        case let (_, existing?, _):
            return .existingBranch(existing)
        case let (base, nil, nil):
            return .newBranch(from: base)
        }
    }
}

public enum AgentStartBranch: Sendable, Equatable {
    case found(ExistingBranch)
    case refused(String)

    public static func listing(of repo: Repo, store: Store) async -> [ExistingBranch] {
        async let local = Git.branches(of: repo.path)
        async let remote = Git.remoteBranches(of: repo.path)
        async let worktrees = Git.worktrees(of: repo.path)
        async let remoteNames = Git.remoteNames(of: repo.path)

        let holders = BranchHolder.byBranch(
            worktrees: (try? await worktrees) ?? [],
            projectPath: repo.path,
            workspaceNames: BranchHolder.names(
                of: (try? await store.workspaces(repoID: repo.id)) ?? [], in: repo.id
            )
        )
        return WorkspaceCheckoutPlan.everyBranch(
            local: (try? await local) ?? [], remote: (try? await remote) ?? [], inUse: holders,
            remoteNames: (try? await remoteNames) ?? []
        )
    }

    public static func find(
        _ name: String, among branches: [ExistingBranch], project: String
    ) -> AgentStartBranch {
        let wanted = WorkspaceCheckoutPlan.remoteBranchName(name) ?? name

        if let branch = branches.first(where: { $0.name == wanted }) {
            guard let holder = branch.inUseBy else { return .found(branch) }
            return .refused(holder.agentRefusal(branch: branch.name))
        }

        guard !branches.isEmpty else {
            return .refused(
                "Unified Dev found no branches in the project '\(project)' to continue on. It may have "
                    + "no commits yet, or Unified Dev may no longer be able to read the repository. "
                    + "Leave existing_branch out to have Unified Dev cut a new branch, which says what "
                    + "is wrong if it cannot."
            )
        }

        return .refused(
            "The project '\(project)' has no branch called '\(name)', locally or on the remote. "
                + "It has " + BridgeProjectLookup.listing(branches.map(\.name)) + ". Ask again "
                + "with one of those as existing_branch, or leave existing_branch out to cut a "
                + "new branch from the project's default branch."
        )
    }
}
