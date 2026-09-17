import Foundation

extension WorkspaceManager {
    public func refreshBranch(workspace: Workspace) async {
        guard workspace.state == .active, !Task.isCancelled,
              let result = try? await Git.run(
                  ["rev-parse", "--show-toplevel", "--abbrev-ref", "HEAD"], in: workspace.path
              ), result.ok else { return }
        let lines = result.lines
        guard lines.count == 2,
              URL(fileURLWithPath: lines[0]).resolvingSymlinksInPath().path
                == URL(fileURLWithPath: workspace.path).resolvingSymlinksInPath().path,
              lines[1] != "HEAD", Git.isValidBranchName(lines[1]),
              lines[1] != workspace.branch, lines[1] != workspace.baseBranch,
              let repo = try? await store.repo(id: workspace.repoID),
              lines[1] != repo.defaultBranch,
              !Task.isCancelled else { return }

        guard Git.isValidBranchName(workspace.branch),
              let old = try? await Git.run(
                  ["show-ref", "--verify", "--quiet", "--", "refs/heads/\(workspace.branch)"],
                  in: workspace.path
              ), old.status == 1, !Task.isCancelled else { return }
        try? await store.updateCheckedOutBranch(lines[1], observed: workspace)
    }
}
