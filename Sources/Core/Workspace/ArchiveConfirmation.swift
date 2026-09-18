import Foundation

public struct ArchiveHazards: Sendable, Hashable {
    public var isAgentMidTurn: Bool
    public var isPullRequestMerged: Bool
    public var isDeletingBranch: Bool

    public init(
        isAgentMidTurn: Bool = false,
        isPullRequestMerged: Bool = false,
        isDeletingBranch: Bool = false
    ) {
        self.isAgentMidTurn = isAgentMidTurn
        self.isPullRequestMerged = isPullRequestMerged
        self.isDeletingBranch = isDeletingBranch
    }

    public var liveLosses: [String] {
        isAgentMidTurn
            ? ["the turn an agent in this workspace has not finished, which is not in git yet"]
            : []
    }
}

public struct ArchiveRequest: Identifiable, Sendable {
    public enum Severity: Sendable, Hashable {
        case routine
        case worthMentioning
        case destructive
    }

    public let id = UUID()
    public var workspace: Workspace
    public var report: WorkspaceSafetyReport
    public var deleteBranch: Bool?
    public var problem: String?
    public var hazards: ArchiveHazards

    public init(
        workspace: Workspace,
        report: WorkspaceSafetyReport,
        deleteBranch: Bool? = nil,
        problem: String? = nil,
        hazards: ArchiveHazards = ArchiveHazards()
    ) {
        self.workspace = workspace
        self.report = report
        self.deleteBranch = deleteBranch
        self.problem = problem
        self.hazards = hazards
    }

    public var losses: [String] {
        hazards.liveLosses + report.irreversibleLosses(
            deletingBranch: hazards.isDeletingBranch,
            isPullRequestMerged: hazards.isPullRequestMerged
        )
    }

    public var notes: [String] {
        report.ignoredFileNotes
    }

    public var severity: Severity {
        if problem != nil { return .destructive }
        if !losses.isEmpty { return .destructive }
        return notes.isEmpty ? .routine : .worthMentioning
    }

    public var isDestructive: Bool { severity == .destructive }

    public static let uncheckedOnConfirming =
        "Unified Dev could not check this workspace again for work written since you were asked."

    public func reconfirmation(isAgentMidTurn: Bool, report fresh: WorkspaceSafetyReport?) -> ArchiveRequest? {
        guard !hazards.isAgentMidTurn else { return nil }
        var now = hazards
        now.isAgentMidTurn = isAgentMidTurn
        guard let fresh else {
            guard problem == nil || isAgentMidTurn else { return nil }
            return ArchiveRequest(
                workspace: workspace, report: report, deleteBranch: deleteBranch,
                problem: problem ?? Self.uncheckedOnConfirming, hazards: now
            )
        }
        let atRisk = isAgentMidTurn || fresh.putsMoreAtRisk(
            than: report, deletingBranch: now.isDeletingBranch, isPullRequestMerged: now.isPullRequestMerged
        )
        guard atRisk else { return nil }
        return ArchiveRequest(workspace: workspace, report: fresh, deleteBranch: deleteBranch, hazards: now)
    }

    public var confirmLabel: String {
        isDestructive ? "Archive and lose that work" : "Archive"
    }

    public var cancelLabel: String { "Keep the workspace" }

    public var message: String {
        var text = "\u{201C}\(workspace.name)\u{201D}\n\n"
        if let path = report.preservedFolderPath {
            text += "Git no longer recognizes this folder as a worktree. "
            text += "The folder at \(path) and the branch are kept. The archive script is skipped."
        } else {
            text += "The worktree is deleted and the branch is "
            text += hazards.isDeletingBranch ? "deleted too." : "kept."
        }
        text += " The workspace moves to Archived."

        if hazards.isPullRequestMerged, !isDestructive {
            text += " Its pull request is merged, so the branch\u{2019}s work is already on the "
            text += "default branch."
        }

        let losses = losses
        if !losses.isEmpty {
            text += "\n\nThis would lose:\n"
            text += losses.map { "\u{2022} \($0)" }.joined(separator: "\n")
        }

        let notes = notes
        if !notes.isEmpty {
            text += "\n\nAlso in the worktree, ignored by git and so in no commit by design:\n"
            text += notes.map { "\u{2022} \($0)" }.joined(separator: "\n")
        }

        if let problem {
            text += "\n\n\(problem)"
        }
        return text
    }
}

extension WorkspaceSafetyReport {
    func putsMoreAtRisk(than shown: WorkspaceSafetyReport, deletingBranch: Bool, isPullRequestMerged: Bool) -> Bool {
        let lostWithBranch = { (report: WorkspaceSafetyReport) -> Int in
            let isHeld = !deletingBranch || report.isBranchMerged || isPullRequestMerged
            return isHeld ? 0 : report.unpushedCommits
        }
        return (hasUncommittedChanges && !shown.hasUncommittedChanges)
            || !Set(untrackedFiles).isSubset(of: shown.untrackedFiles)
            || !Set(modifiedIgnoredFiles).isSubset(of: shown.modifiedIgnoredFiles)
            || detachedCommits > shown.detachedCommits
            || lostWithBranch(self) > lostWithBranch(shown)
    }
}
