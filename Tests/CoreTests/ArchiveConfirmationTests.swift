import Testing
import Foundation
@testable import Core

@Suite("Archive confirmation")
struct ArchiveConfirmationTests {
    private func makeWorkspace(name: String = "Fix the login redirect") -> Workspace {
        Workspace(
            repoID: .new(),
            name: name,
            branch: "unifieddev/fix-the-login-redirect",
            path: "/tmp/unifieddev/fix-the-login-redirect",
            baseBranch: "main"
        )
    }

    private let ownersIgnoredPaths = [
        ".env",
        "resources/js/actions/",
        "resources/js/routes/",
        "resources/js/types/",
        "storage/app/attachments/",
        "storage/app/private/",
        "storage/app/public/",
        "storage/framework/cache/",
        "storage/framework/sessions/",
        "storage/framework/testing/",
        "storage/framework/views/",
        "storage/logs/",
        "public/hot",
    ]

    @Test("an unrecognized folder confirmation explains what is kept")
    func unrecognizedFolderIsKept() {
        let workspace = makeWorkspace()
        var report = WorkspaceSafetyReport()
        report.preservedFolderPath = workspace.path
        let request = ArchiveRequest(
            workspace: workspace, report: report,
            hazards: ArchiveHazards(isDeletingBranch: true)
        )

        #expect(request.confirmLabel == "Archive")
        #expect(request.losses.isEmpty)
        #expect(request.message.contains("The folder at \(workspace.path) and the branch are kept."))
        #expect(request.message.contains("The archive script is skipped."))
        #expect(!request.message.contains("is deleted"))
    }

    @Test("nothing at stake and a merged pull request reads as routine")
    func cleanAndMergedIsRoutine() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(),
            hazards: ArchiveHazards(isPullRequestMerged: true)
        )

        #expect(request.severity == .routine)
        #expect(request.isDestructive == false)
        #expect(request.confirmLabel == "Archive")
        #expect(request.message == """
        \u{201C}Fix the login redirect\u{201D}

        The worktree is deleted and the branch is kept. The workspace moves to Archived. Its pull \
        request is merged, so the branch\u{2019}s work is already on the default branch.
        """)
    }

    @Test("ignored files that differ are mentioned, never called a loss")
    func ignoredFilesAreMentionedNotWarnedAbout() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(modifiedIgnoredFiles: ownersIgnoredPaths),
            hazards: ArchiveHazards(isPullRequestMerged: true)
        )

        #expect(request.severity == .worthMentioning)
        #expect(request.isDestructive == false)
        #expect(request.confirmLabel == "Archive")
        #expect(request.losses.isEmpty)
        #expect(request.message.contains("lose") == false)
        #expect(request.message == """
        \u{201C}Fix the login redirect\u{201D}

        The worktree is deleted and the branch is kept. The workspace moves to Archived. Its pull \
        request is merged, so the branch\u{2019}s work is already on the default branch.

        Also in the worktree, ignored by git and so in no commit by design:
        \u{2022} 13 ignored files and folders that differ from the main checkout: .env, \
        resources/js/actions/, resources/js/routes/, resources/js/types/, \
        storage/app/attachments/, and 8 more
        """)
    }

    @Test("uncommitted changes to tracked files keep the strong wording")
    func uncommittedChangesStayStrong() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(hasUncommittedChanges: true),
            hazards: ArchiveHazards(isPullRequestMerged: true)
        )

        #expect(request.severity == .destructive)
        #expect(request.confirmLabel == "Archive and lose that work")
        #expect(request.message == """
        \u{201C}Fix the login redirect\u{201D}

        The worktree is deleted and the branch is kept. The workspace moves to Archived.

        This would lose:
        \u{2022} uncommitted changes to tracked files
        """)
    }

    @Test("a commit on a detached HEAD keeps the strong wording")
    func detachedCommitsStayStrong() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(detachedCommits: 1),
            hazards: ArchiveHazards(isPullRequestMerged: true)
        )

        #expect(request.severity == .destructive)
        #expect(request.confirmLabel == "Archive and lose that work")
        #expect(request.message == """
        \u{201C}Fix the login redirect\u{201D}

        The worktree is deleted and the branch is kept. The workspace moves to Archived.

        This would lose:
        \u{2022} 1 commit made on a detached HEAD, held by no branch
        """)
    }

    @Test("a report git could not fill in is unknown, never nothing at stake")
    func anUnansweredCheckStaysStrong() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(),
            problem: "Unified Dev could not check this workspace for unsaved work. The worktree for "
                + "\u{201C}Fix the login redirect\u{201D} is no longer on disk.",
            hazards: ArchiveHazards(isPullRequestMerged: true)
        )

        #expect(request.severity == .destructive)
        #expect(request.isDestructive)
        #expect(request.confirmLabel == "Archive and lose that work")
        #expect(request.message == """
        \u{201C}Fix the login redirect\u{201D}

        The worktree is deleted and the branch is kept. The workspace moves to Archived.

        Unified Dev could not check this workspace for unsaved work. The worktree for \
        \u{201C}Fix the login redirect\u{201D} is no longer on disk.
        """)
    }

    @Test("an agent mid turn is the first loss listed, because git cannot see it")
    func aRunningAgentLeadsTheList() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(hasUncommittedChanges: true),
            hazards: ArchiveHazards(isAgentRunning: true)
        )

        #expect(request.severity == .destructive)
        #expect(request.losses.first?.contains("an agent is running") == true)
    }

    @Test("an agent waiting for permission is mid turn, so the turn is a loss even when git could not be asked")
    func anAgentAwaitingPermissionIsMidTurn() {
        #expect(!ArchiveHazards.isAgentMidTurn(isRunning: false, isAwaitingPermission: false))
        #expect(ArchiveHazards.isAgentMidTurn(isRunning: true, isAwaitingPermission: false))
        #expect(ArchiveHazards.isAgentMidTurn(isRunning: false, isAwaitingPermission: true))

        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(),
            problem: "Unified Dev could not check this workspace for unsaved work.",
            hazards: ArchiveHazards(
                isAgentRunning: ArchiveHazards.isAgentMidTurn(isRunning: false, isAwaitingPermission: true)
            )
        )

        #expect(request.isDestructive)
        #expect(request.losses.first?.contains("an agent is running") == true)
    }

    @Test("a merged pull request never quietens a real loss")
    func mergedNeverSoftensARealLoss() {
        for report in [
            WorkspaceSafetyReport(hasUncommittedChanges: true),
            WorkspaceSafetyReport(untrackedFiles: ["plan.md"]),
            WorkspaceSafetyReport(detachedCommits: 2),
        ] {
            let request = ArchiveRequest(
                workspace: makeWorkspace(),
                report: report,
                hazards: ArchiveHazards(isPullRequestMerged: true, isDeletingBranch: true)
            )
            #expect(request.severity == .destructive)
            #expect(request.message.contains("already on the default branch") == false)
        }
    }

    @Test("the branch's fate is stated either way")
    func theBranchIsAlwaysAccountedFor() {
        let kept = ArchiveRequest(workspace: makeWorkspace(), report: WorkspaceSafetyReport())
        #expect(kept.message.contains("the branch is kept."))

        let deleted = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(),
            hazards: ArchiveHazards(isDeletingBranch: true)
        )
        #expect(deleted.message.contains("the branch is deleted too."))
    }

    @Test("ignored files are still listed beside a real loss, under their own calmer heading")
    func ignoredFilesKeepTheirOwnHeadingBesideALoss() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(
                hasUncommittedChanges: true, modifiedIgnoredFiles: [".env"]
            )
        )

        #expect(request.confirmLabel == "Archive and lose that work")
        #expect(request.losses == ["uncommitted changes to tracked files"])
        #expect(request.notes == ["1 ignored file that differs from the main checkout: .env"])
        #expect(request.message.contains("This would lose:\n\u{2022} uncommitted changes"))
        #expect(request.message.contains("Also in the worktree, ignored by git"))
    }

    @Test("the whole list is still one voice for the error that refuses an archive")
    func theErrorPathStillSeesEverything() {
        let report = WorkspaceSafetyReport(
            hasUncommittedChanges: true, modifiedIgnoredFiles: [".env"], detachedCommits: 1
        )
        #expect(report.losses(deletingBranch: true).count == 3)
        #expect(
            report.losses(deletingBranch: true)
                == report.irreversibleLosses(deletingBranch: true) + report.ignoredFileNotes
        )
    }
}
