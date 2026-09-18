import Foundation

public enum StartingPointPick: Equatable, Sendable {
    case use(WorkspaceStartingPoint)
    case goTo(WorkspaceID)
    case refuse(String)
    case lookUp(String)

    public static func decide(
        _ source: WorkspaceSource,
        holders: [String: BranchHolder],
        taken: Set<String>,
        repoID: RepoID,
        workspaces: [Workspace]
    ) -> Self {
        switch source {
        case .newBranch(let base):
            return .use(.newBranch(from: base))
        case .pullRequest(.typed(_, let text)):
            return .lookUp(text)
        case .existingBranch(let branch):
            return decide(checkout: .branch(branch), holders: holders, taken: taken, repoID: repoID, workspaces: workspaces)
        case .pullRequest(.listed(let request)):
            return decide(checkout: .pullRequest(request), holders: holders, taken: taken, repoID: repoID, workspaces: workspaces)
        }
    }

    public static func decide(
        checkout: WorkspaceCheckout,
        holders: [String: BranchHolder],
        taken: Set<String>,
        repoID: RepoID,
        workspaces: [Workspace]
    ) -> Self {
        let branch = WorkspaceCheckoutPlan.localBranch(for: checkout, taken: taken)
        guard let holder = holders[branch] else { return .use(WorkspaceStartingPoint(checkout)) }
        if holder.isAppWorkspace,
           let held = WorkspaceCheckoutPlan.workspaceHolding(branch: branch, in: repoID, among: workspaces) {
            return .goTo(held.id)
        }
        return .refuse(holder.refusal(branch: branch))
    }
}
