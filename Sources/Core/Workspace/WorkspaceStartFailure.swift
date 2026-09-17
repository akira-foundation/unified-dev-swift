import Foundation

public enum WorkspaceStartTrouble: Sendable, Equatable {
    case projectMissingFromDisk(project: String, path: String)
    case noCommitsYet(project: String)
    case baseBranchMissing(branch: String, project: String, wasRequested: Bool, branches: [String])
    case unexplained(String)

    public var sentence: String {
        switch self {
        case let .projectMissingFromDisk(project, path):
            return """
                Unified Dev could not start that workspace because the project '\(project)' is no longer \
                on disk at \(path). It has been moved, renamed or deleted since Unified Dev recorded it, \
                so there is no repository left to cut a worktree from. Retrying will not help. \
                Tell the owner where the project went.
                """

        case let .noCommitsYet(project):
            return """
                Unified Dev could not start that workspace because the project '\(project)' has no \
                commits yet. A worktree is cut from a commit, so there is nothing to start from \
                until the first one is made. No branch name will work, so do not retry with \
                another one. Say so and carry on with your own work.
                """

        case let .baseBranchMissing(branch, project, wasRequested, branches):
            let opening = wasRequested
                ? "Unified Dev could not start that workspace because the project '\(project)' has no "
                    + "branch called '\(branch)'."
                : "Unified Dev could not start that workspace because '\(branch)', the default branch "
                    + "Unified Dev cuts from when a call does not name one, does not exist in the "
                    + "project '\(project)'."
            guard !branches.isEmpty else {
                return opening + " It has no branches at all, so there is nothing to cut from. "
                    + "Do not retry with another name. Say so and carry on with your own work."
            }
            let whichBranches = Self.listing(branches)
            let hasOne = branches.count == 1
            return opening
                + (hasOne ? " Its only branch is \(whichBranches)." : " Its branches are \(whichBranches).")
                + (hasOne
                    ? " Call workspace_start again with that as base_branch."
                    : " Call workspace_start again with one of those as base_branch.")

        case let .unexplained(message):
            return "Unified Dev could not start that workspace: \(message)"
        }
    }

    public static func diagnose(
        _ error: any Error,
        project: String,
        projectPath: String,
        baseBranch: String,
        wasRequested: Bool
    ) async -> WorkspaceStartTrouble {
        switch await CheckoutStanding.of(projectPath, branch: baseBranch) {
        case .missing, .notACheckout:
            return .projectMissingFromDisk(project: project, path: projectPath)

        case .noCommitsYet:
            return .noCommitsYet(project: project)

        case .branchMissing(let branch):
            let branches = (try? await Git.branches(of: projectPath)) ?? []
            return .baseBranchMissing(
                branch: branch,
                project: project,
                wasRequested: wasRequested,
                branches: branches
            )

        case .fine:
            return .unexplained(CheckoutStanding.complaint(about: error))
        }
    }

    private static func listing(_ branches: [String]) -> String {
        let shown = branches.prefix(10).map { "'\($0)'" }
        let rest = branches.count - shown.count
        guard let last = shown.last else { return "" }
        var text = shown.count == 1
            ? last
            : shown.dropLast().joined(separator: ", ") + " and " + last
        if rest > 0 { text += ", and \(rest) more" }
        return text
    }
}
