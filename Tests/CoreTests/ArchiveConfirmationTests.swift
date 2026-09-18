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
            hazards: ArchiveHazards(isAgentMidTurn: true)
        )

        #expect(request.severity == .destructive)
        #expect(request.losses.first?.contains("an agent in this workspace has not finished") == true)
    }

    @Test("an agent waiting for permission is mid turn, so the turn is a loss even when git could not be asked")
    func anAgentAwaitingPermissionIsMidTurn() {
        let request = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(),
            problem: "Unified Dev could not check this workspace for unsaved work.",
            hazards: ArchiveHazards(
                isAgentMidTurn: AgentTurns.isMidTurn(isRunning: false, isAwaitingPermission: true)
            )
        )

        #expect(request.isDestructive)
        #expect(request.losses.first?.contains("an agent in this workspace has not finished") == true)
        #expect(request.losses.first?.contains("running") == false)
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

    @Test("a turn that started while the confirmation was open is asked about before anything is removed")
    func aTurnStartedDuringTheQuestionAsksAgain() throws {
        let shown = ArchiveRequest(workspace: makeWorkspace(), report: WorkspaceSafetyReport())

        let again = try #require(shown.reconfirmation(isAgentMidTurn: true, report: WorkspaceSafetyReport()))

        #expect(again.isDestructive)
        #expect(again.losses.first?.contains("an agent in this workspace has not finished") == true)
    }

    @Test("work written while the confirmation was open is asked about before anything is removed")
    func workWrittenDuringTheQuestionAsksAgain() throws {
        let shown = ArchiveRequest(workspace: makeWorkspace(), report: WorkspaceSafetyReport())
        let written = WorkspaceSafetyReport(hasUncommittedChanges: true)

        let again = try #require(shown.reconfirmation(isAgentMidTurn: false, report: written))

        #expect(again.report == written)
        #expect(!again.losses.isEmpty)
    }

    @Test("confirming goes ahead when nothing would be lost that the question did not show")
    func nothingNewGoesAhead() {
        let dirty = WorkspaceSafetyReport(hasUncommittedChanges: true)
        let shown = ArchiveRequest(
            workspace: makeWorkspace(), report: dirty, hazards: ArchiveHazards(isAgentMidTurn: true)
        )

        #expect(shown.reconfirmation(isAgentMidTurn: true, report: dirty) == nil)
        #expect(shown.reconfirmation(isAgentMidTurn: false, report: WorkspaceSafetyReport()) == nil)
    }

    @Test("a check that still cannot run keeps the answer already given to it")
    func aCheckThatStillFailsGoesAhead() {
        let shown = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(),
            problem: "Unified Dev could not check this workspace for unsaved work."
        )

        #expect(shown.reconfirmation(isAgentMidTurn: false, report: nil) == nil)
    }

    @Test("a check that works now names the work the first question could not")
    func aCheckThatWorksNowNamesTheLoss() throws {
        let shown = ArchiveRequest(
            workspace: makeWorkspace(),
            report: WorkspaceSafetyReport(),
            problem: "Unified Dev could not check this workspace for unsaved work."
        )

        let again = try #require(
            shown.reconfirmation(isAgentMidTurn: false, report: WorkspaceSafetyReport(untrackedFiles: ["plan.md"]))
        )

        #expect(again.problem == nil)
        #expect(again.losses.contains { $0.contains("plan.md") })
    }

    @Test("a check that fails at the moment of confirming asks again, and says it could not look")
    func aCheckThatFailsOnConfirmingAsksAgain() throws {
        let shown = ArchiveRequest(workspace: makeWorkspace(), report: WorkspaceSafetyReport())

        let again = try #require(shown.reconfirmation(isAgentMidTurn: false, report: nil))

        #expect(again.problem == ArchiveRequest.uncheckedOnConfirming)
        #expect(again.isDestructive)
    }

    @Test("an ignored file changed while the question was open is asked about")
    func anIgnoredFileChangedDuringTheQuestionAsksAgain() {
        let shown = ArchiveRequest(workspace: makeWorkspace(), report: WorkspaceSafetyReport())
        let edited = WorkspaceSafetyReport(modifiedIgnoredFiles: [".env.local"])

        #expect(shown.reconfirmation(isAgentMidTurn: false, report: edited) != nil)
    }

    @Test("less of something the question already named goes ahead")
    func lessOfWhatWasNamedGoesAhead() {
        let shown = ArchiveRequest(
            workspace: makeWorkspace(), report: WorkspaceSafetyReport(untrackedFiles: ["a", "b", "c"])
        )

        #expect(shown.reconfirmation(isAgentMidTurn: false, report: WorkspaceSafetyReport(untrackedFiles: ["a", "b"])) == nil)
    }

    @Test("a file swapped for another beyond the five the question named is asked about")
    func aSwapPastTheNamedFiveAsksAgain() {
        let seven = ["a", "b", "c", "d", "e", "f", "g"]
        let shown = ArchiveRequest(workspace: makeWorkspace(), report: WorkspaceSafetyReport(untrackedFiles: seven))
        let swapped = WorkspaceSafetyReport(untrackedFiles: ["a", "b", "c", "d", "e", "f", "h"])

        #expect(Set(shown.losses) == Set(ArchiveRequest(workspace: makeWorkspace(), report: swapped).losses))
        #expect(shown.reconfirmation(isAgentMidTurn: false, report: swapped) != nil)
    }

    @Test("a turn already named as lost does not ask again for what it writes")
    func anAcceptedTurnDoesNotAskAgain() {
        let shown = ArchiveRequest(
            workspace: makeWorkspace(), report: WorkspaceSafetyReport(), hazards: ArchiveHazards(isAgentMidTurn: true)
        )
        let written = WorkspaceSafetyReport(hasUncommittedChanges: true, untrackedFiles: ["step-4.md"], unpushedCommits: 2)

        #expect(shown.reconfirmation(isAgentMidTurn: true, report: written) == nil)
        #expect(shown.reconfirmation(isAgentMidTurn: false, report: written) == nil)
    }

    @Test("commits made while the question was open matter only when the branch goes too")
    func newCommitsMatterOnlyWithTheBranch() {
        let before = WorkspaceSafetyReport(unpushedCommits: 1)
        let after = WorkspaceSafetyReport(unpushedCommits: 3)
        let keeping = ArchiveRequest(
            workspace: makeWorkspace(), report: before, hazards: ArchiveHazards(isDeletingBranch: false)
        )
        let deleting = ArchiveRequest(
            workspace: makeWorkspace(), report: before, hazards: ArchiveHazards(isDeletingBranch: true)
        )

        #expect(keeping.reconfirmation(isAgentMidTurn: false, report: after) == nil)
        #expect(deleting.reconfirmation(isAgentMidTurn: false, report: after) != nil)
    }

    @Test("a confirmed archive deletes the branch only when the question said it would")
    func theBranchChoiceIsTheQuestions() {
        let keeping = ArchiveRequest(
            workspace: makeWorkspace(), report: WorkspaceSafetyReport(), hazards: ArchiveHazards(isDeletingBranch: false)
        )
        let deleting = ArchiveRequest(
            workspace: makeWorkspace(), report: WorkspaceSafetyReport(), hazards: ArchiveHazards(isDeletingBranch: true)
        )
        let chosen = ArchiveRequest(
            workspace: makeWorkspace(), report: WorkspaceSafetyReport(), deleteBranch: false,
            hazards: ArchiveHazards(isDeletingBranch: false)
        )

        #expect(!keeping.deletesBranch)
        #expect(deleting.deletesBranch)
        #expect(!chosen.deletesBranch)
    }
}
