import Foundation

extension WorkspaceManager {
    public func refreshBranch(workspace: Workspace) async {
        guard workspace.state == .active, !Task.isCancelled,
              let checkedOut = Git.headBranch(in: workspace.path),
              checkedOut != "HEAD", Git.isValidBranchName(checkedOut),
              checkedOut != workspace.branch, checkedOut != workspace.baseBranch,
              let repo = try? await store.repo(id: workspace.repoID),
              checkedOut != repo.defaultBranch,
              !Task.isCancelled else { return }

        guard Git.isValidBranchName(workspace.branch),
              let old = try? await Git.run(
                  ["show-ref", "--verify", "--quiet", "--", "refs/heads/\(workspace.branch)"],
                  in: workspace.path
              ), old.status == 1, !Task.isCancelled else { return }
        try? await store.updateCheckedOutBranch(checkedOut, observed: workspace)
    }
}
