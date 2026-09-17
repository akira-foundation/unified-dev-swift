import Foundation

public struct WorkspaceNamingResult: Sendable, Hashable {
    public var workspace: Workspace
    public var didRename: Bool
    public var branchRefusal: BranchRenameRefusal?

    public init(workspace: Workspace, didRename: Bool, branchRefusal: BranchRenameRefusal? = nil) {
        self.workspace = workspace
        self.didRename = didRename
        self.branchRefusal = branchRefusal
    }

    public var notice: String? {
        guard didRename, let branchRefusal else { return nil }
        return WorkspaceNaming.branchNotice(
            name: workspace.name,
            branch: workspace.branch,
            refusal: branchRefusal
        )
    }
}

extension WorkspaceManager {
    public func branchRenameFacts(
        workspace: Workspace,
        desiredBranch: String,
        hasPullRequest: Bool
    ) async throws -> BranchRenameFacts {
        async let checkedOut = try? Git.currentBranch(of: workspace.path)
        async let ahead = try? Git.commitsAhead(worktree: workspace.path, base: workspace.baseBranch)
        async let upstream = try? Git.upstream(of: workspace.branch, in: workspace.path)
        async let remote = Git.hasRemoteCounterpart(workspace.branch, in: workspace.path)
        async let inProgress = Git.hasOperationInProgress(in: workspace.path)
        async let branches = try? Git.branches(of: workspace.path)

        return BranchRenameFacts(
            recordedBranch: workspace.branch,
            checkedOutBranch: await checkedOut,
            desiredBranch: desiredBranch,
            commitsAhead: await ahead ?? 1,
            hasUpstream: (await upstream) != nil,
            hasRemoteCounterpart: await remote,
            hasPullRequest: hasPullRequest,
            hasOperationInProgress: await inProgress,
            takenBranches: Set(await branches ?? [])
        )
    }

    public func applyName(
        _ suggestion: WorkspaceNameSuggestion,
        to workspaceID: WorkspaceID,
        placeholder: String,
        hasPullRequest: Bool
    ) async throws -> WorkspaceNamingResult? {
        guard let current = try await store.workspace(id: workspaceID) else { return nil }

        guard WorkspaceNaming.mayApplyName(current: current.name, placeholder: placeholder) else {
            return WorkspaceNamingResult(workspace: current, didRename: false)
        }

        var renamed = current
        var refusal: BranchRenameRefusal?

        let facts = try await branchRenameFacts(
            workspace: current,
            desiredBranch: suggestion.branch,
            hasPullRequest: hasPullRequest
        )

        switch BranchRenameGate.decide(facts) {
        case .rename(let branch):
            do {
                try await Git.renameBranch(current.branch, to: branch, in: current.path)
                renamed.branch = branch
            } catch {
                refusal = .gitRefused(error.readableMessage)
            }
        case .refuse(let reason):
            refusal = reason
        }

        renamed.name = suggestion.name

        let name = renamed.name
        let branch = renamed.branch
        let saved = try await store.update(workspaceID: workspaceID) {
            $0.name = name
            $0.branch = branch
        }
        guard let saved else { return nil }
        return WorkspaceNamingResult(workspace: saved, didRename: true, branchRefusal: refusal)
    }
}
