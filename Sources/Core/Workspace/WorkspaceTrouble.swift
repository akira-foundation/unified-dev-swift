import Foundation

public enum WorkspaceTrouble: Sendable, Equatable {
    case projectGone(project: String, path: String)
    case projectNotACheckout(project: String, path: String)
    case projectHasNoCommits(project: String)
    case baseBranchGone(branch: String, project: String)
    case createBranchInUse(branch: String, holder: BranchHolder)
    case worktreeGone(workspace: String)
    case worktreeNotACheckout(workspace: String)
    case worktreeBaseBranchGone(branch: String, workspace: String)
    case archiveWorktreeGone(workspace: String)
    case archiveWorktreeNotACheckout(workspace: String, path: String)
    case archiveWorktreeNotEmpty(workspace: String)
    case archiveUnexplained(workspace: String, complaint: String)
    case restoreBranchInUse(branch: String, workspace: String, worktree: String)
    case restoreBranchGone(branch: String, workspace: String)
    case restoreUnexplained(workspace: String, complaint: String)
    case continueUnexplained(workspace: String, complaint: String)
    case recordUnwritable(workspace: String, complaint: String)
    case transcriptUnwritable(complaint: String)
    case reviewCommentUnwritable(complaint: String)
    case unexplained(String)

    public var sentence: String {
        switch self {
        case let .projectGone(project, path):
            return """
                The project '\(project)' is no longer at \(path).

                It has been moved, renamed or deleted since Unified Dev recorded it, so there is no \
                repository left to cut a worktree from.

                Put the folder back, or remove the project from the sidebar and add it again \
                where it lives now.
                """

        case let .projectNotACheckout(project, path):
            return """
                The folder for the project '\(project)' is still at \(path), but it is not a \
                git repository any more.

                Every worktree is cut from the project's own repository, so nothing can be \
                created here until git knows that folder again.

                Restore it, or remove the project from the sidebar and add it again wherever the \
                repository is now.
                """

        case let .projectHasNoCommits(project):
            return """
                The project '\(project)' has no commits yet.

                A worktree is cut from a commit, so there is nothing to start from until the \
                first one is made.

                Make a commit in the project and try again.
                """

        case let .baseBranchGone(branch, project):
            return """
                The project '\(project)' has no branch called '\(branch)' any more, so there \
                is nothing to cut this worktree from.

                Choose another base branch, or put that one back.
                """

        case let .createBranchInUse(branch, holder):
            return """
                The branch '\(branch)' is already checked out in \(holder.described).

                Git allows one worktree per branch, so a second workspace on it cannot be made. \
                Nothing has been created and nothing has been changed.

                \(holder.wayOut), or start a new branch from '\(branch)' on the Create new \
                branch tab, which git does allow and which gets you the same code.
                """

        case let .worktreeGone(workspace):
            return """
                The worktree for '\(workspace)' is not on disk any more.

                Something outside Unified Dev deleted the folder this workspace was working in, so \
                there are no changes left to read.

                Its branch is still in the project, so archive this workspace and start a new one \
                from that branch to carry on.
                """

        case let .worktreeNotACheckout(workspace):
            return """
                The folder for '\(workspace)' is still there, but git does not know it as a \
                worktree any more, which is what a folder that was deleted and then recreated \
                looks like.

                Its branch is still in the project, so archive this workspace and start a new one \
                from that branch to carry on.
                """

        case let .worktreeBaseBranchGone(branch, workspace):
            return """
                '\(branch)', the branch '\(workspace)' is measured against, is not in the \
                project any more, so there is nothing to compare this worktree with.

                Put that branch back, or give the workspace a base branch that is still there.
                """

        case let .archiveWorktreeGone(workspace):
            return """
                The worktree for '\(workspace)' is not on disk any more.

                Something outside Unified Dev deleted the folder, so there is no unsaved work left in \
                it and nothing left to remove.

                Archiving it destroys nothing that is still there.
                """

        case let .archiveWorktreeNotACheckout(workspace, path):
            return """
                The folder for '\(workspace)' is still at \(path), and git does not know it as \
                a worktree any more, which is what a folder that was deleted and then recreated \
                looks like.

                Its files have been kept. Try archiving again. Unified Dev keeps folders that git \
                no longer recognizes as a worktree.
                """

        case let .archiveWorktreeNotEmpty(workspace):
            return """
                The worktree for '\(workspace)' holds files that are in no commit, and Unified Dev \
                will not delete a worktree holding work that is nowhere else. Nothing has been \
                removed.

                Unified Dev looks for unsaved work before it runs the archive script, so files that \
                appeared after that, a log or a dump the script left behind, are the usual reason \
                for this.

                Archive again and the confirmation will list what is there, so you can look \
                before you go ahead.
                """

        case let .archiveUnexplained(workspace, complaint):
            return """
                Archiving '\(workspace)' stopped, and Unified Dev cannot say why.

                Its worktree is still a checkout in good order and holds nothing that is not \
                committed, so this is neither a folder that has moved nor work standing in the \
                way. Nothing has been removed.

                The reason given was: \(complaint)
                """

        case let .restoreBranchInUse(branch, workspace, worktree):
            return """
                The branch '\(branch)' is already checked out in the worktree at \(worktree), \
                and git allows one worktree per branch, so there is nowhere to bring \
                '\(workspace)' back to.

                Another workspace on the same branch is the usual reason.

                Archive that one, or delete that folder if it is not one of Unified Dev's, and try \
                again.
                """

        case let .restoreBranchGone(branch, workspace):
            return """
                The branch '\(branch)' is not on this Mac and not on any remote Unified Dev can see, \
                so the commits '\(workspace)' held cannot be reached by name and there is nothing \
                to rebuild its worktree from.

                It stays in Archived, still readable.

                If somebody else still has that branch, fetch the project and try again.
                """

        case let .restoreUnexplained(workspace, complaint):
            return """
                Bringing '\(workspace)' back stopped, and Unified Dev cannot say why.

                Its project is a checkout in good order and nothing else is holding its branch, \
                so this is neither a project nor a branch that has gone missing. It stays in \
                Archived, with nothing lost.

                The reason given was: \(complaint)
                """

        case let .continueUnexplained(workspace, complaint):
            return """
                Continuing '\(workspace)' stopped, and Unified Dev cannot say why.

                Its worktree is still a checkout in good order and the branch it would be cut \
                from is still there, so this is neither a folder that has moved nor a branch that \
                has gone missing. The worktree is where it was, on the branch it was on, with \
                everything in it untouched.

                The reason given was: \(complaint)
                """

        case let .recordUnwritable(workspace, complaint):
            return """
                Unified Dev finished the disk work for '\(workspace)' and could not write the result \
                into its own database, so the sidebar and the archive are showing where this \
                workspace was rather than where it is.

                Nothing in the worktree is at risk; the record is the only thing that is wrong.

                Quit Unified Dev and open it again, and if it happens a second time the database itself \
                needs looking at.

                The database said: \(complaint)
                """

        case let .transcriptUnwritable(complaint):
            return """
                Unified Dev could not write this turn into its own database, so this conversation is \
                missing rows from here on.

                Nothing in the worktree has been touched and every change the agent has made is \
                still there.

                Sending again will fail the same way while the database is refusing writes, so \
                quit Unified Dev and open it again; if it happens a second time the database itself \
                needs looking at.

                The database said: \(complaint)
                """

        case let .reviewCommentUnwritable(complaint):
            return """
                Unified Dev could not save that review comment, so the list is showing what is \
                stored rather than what you typed.

                Nothing in the worktree has been touched and no comment already written has been \
                lost.

                Trying again will fail the same way while the database is refusing writes, so \
                quit Unified Dev and open it again; if it happens a second time the database itself \
                needs looking at.

                The database said: \(complaint)
                """

        case let .unexplained(message):
            return message
        }
    }

    public static func creating(
        _ error: any Error, project: String, projectPath: String, baseBranch: String
    ) async -> WorkspaceTrouble {
        if let inUse = error as? BranchInUse {
            return .createBranchInUse(branch: inUse.branch, holder: inUse.holder)
        }

        switch await CheckoutStanding.of(projectPath, branch: baseBranch) {
        case .missing: return .projectGone(project: project, path: projectPath)
        case .notACheckout: return .projectNotACheckout(project: project, path: projectPath)
        case .noCommitsYet: return .projectHasNoCommits(project: project)
        case .branchMissing(let branch): return .baseBranchGone(branch: branch, project: project)
        case .fine: return .unexplained(CheckoutStanding.complaint(about: error))
        }
    }

    public static func recording(
        transcript: TranscriptStanding, complaint: String
    ) -> WorkspaceTrouble? {
        switch transcript {
        case .gone: return nil
        case .there, .unanswerable: return .transcriptUnwritable(complaint: complaint)
        }
    }

    public static func readingChanges(
        _ error: any Error, workspace: String, path: String, baseBranch: String
    ) async -> WorkspaceTrouble {
        switch await CheckoutStanding.of(path, branch: baseBranch) {
        case .missing: return .worktreeGone(workspace: workspace)
        case .notACheckout: return .worktreeNotACheckout(workspace: workspace)
        case .noCommitsYet: return .worktreeNotACheckout(workspace: workspace)
        case .branchMissing(let branch):
            return .worktreeBaseBranchGone(branch: branch, workspace: workspace)
        case .fine: return .unexplained(CheckoutStanding.complaint(about: error))
        }
    }

    public static func archiving(
        _ error: any Error, workspace: String, path: String, baseBranch: String
    ) async -> WorkspaceTrouble {
        if error is SQLiteError {
            return .recordUnwritable(workspace: workspace, complaint: complaint(about: error))
        }

        switch await CheckoutStanding.of(path, branch: baseBranch) {
        case .missing: return .archiveWorktreeGone(workspace: workspace)
        case .notACheckout:
            return .archiveWorktreeNotACheckout(workspace: workspace, path: path)
        case .noCommitsYet:
            return .archiveWorktreeNotACheckout(workspace: workspace, path: path)
        case .branchMissing(let branch):
            return .worktreeBaseBranchGone(branch: branch, workspace: workspace)
        case .fine:
            let work = try? await Git.localWork(worktree: path)
            if work?.hasUncommitted == true { return .archiveWorktreeNotEmpty(workspace: workspace) }
            return .archiveUnexplained(workspace: workspace, complaint: complaint(about: error))
        }
    }

    public static func continuing(
        _ error: any Error, workspace: String, path: String, baseBranch: String
    ) async -> WorkspaceTrouble {
        if error is SQLiteError {
            return .recordUnwritable(workspace: workspace, complaint: complaint(about: error))
        }

        switch await CheckoutStanding.of(path, branch: baseBranch) {
        case .missing: return .worktreeGone(workspace: workspace)
        case .notACheckout: return .worktreeNotACheckout(workspace: workspace)
        case .noCommitsYet: return .worktreeNotACheckout(workspace: workspace)
        case .branchMissing(let branch):
            return .worktreeBaseBranchGone(branch: branch, workspace: workspace)
        case .fine:
            return .continueUnexplained(workspace: workspace, complaint: complaint(about: error))
        }
    }

    public static func restoring(
        _ error: any Error, workspace: String, branch: String, project: String, projectPath: String
    ) async -> WorkspaceTrouble {
        if error is SQLiteError {
            return .recordUnwritable(workspace: workspace, complaint: complaint(about: error))
        }

        switch await CheckoutStanding.of(projectPath) {
        case .missing: return .projectGone(project: project, path: projectPath)
        case .notACheckout: return .projectNotACheckout(project: project, path: projectPath)
        case .noCommitsYet: return .projectHasNoCommits(project: project)
        case .branchMissing, .fine:
            let worktrees = (try? await Git.worktrees(of: projectPath)) ?? []
            if let holder = worktrees.first(where: { $0.branch == branch }) {
                return .restoreBranchInUse(
                    branch: branch, workspace: workspace, worktree: holder.path
                )
            }
            let isLocal = await Git.branchExists(branch, in: projectPath)
            let isOnARemote = await Git.hasRemoteCounterpart(branch, in: projectPath)
            if !isLocal, !isOnARemote {
                return .restoreBranchGone(branch: branch, workspace: workspace)
            }
            return .restoreUnexplained(workspace: workspace, complaint: complaint(about: error))
        }
    }

    public static func complaint(about error: any Error) -> String {
        error is SQLiteError
            ? TranscriptStanding.complaint(about: error)
            : CheckoutStanding.complaint(about: error)
    }
}
