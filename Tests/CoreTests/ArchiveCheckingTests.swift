import Foundation
import Testing
@testable import Core

@Suite("Asking to archive before the checking is done")
struct ArchiveCheckingTests {
    private func workspace(_ name: String = "Lighthouse") -> Workspace {
        Workspace(
            repoID: RepoID.new(), name: name, branch: "lighthouse",
            path: "/tmp/\(name)", baseBranch: "main"
        )
    }

    @Test("a checking request says so, and says it in the message the reader sees")
    func saysItIsChecking() {
        let request = ArchiveRequest.checking(workspace: workspace(), hazards: ArchiveHazards())

        #expect(request.isChecking)
        #expect(request.message.contains(ArchiveRequest.checkingSentence))
        #expect(request.message.contains("Lighthouse"))
    }

    @Test("while it is checking the button says Archive anyway")
    func theButtonSaysAnyway() {
        let request = ArchiveRequest.checking(workspace: workspace(), hazards: ArchiveHazards())

        #expect(request.confirmLabel == "Archive anyway")
        #expect(request.cancelLabel == "Keep the workspace")
    }

    @Test("while it is checking nothing is called destructive, because nothing is known yet")
    func nothingIsDestructiveYet() {
        let request = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isDeletingBranch: true)
        )

        #expect(!request.isDestructive)
        #expect(request.severity == .routine)
    }

    @Test("a checking request claims no notes, even handed a report that has some")
    func nothingIsClaimed() {
        let reading = ArchiveRequest(
            workspace: workspace(),
            report: WorkspaceSafetyReport(modifiedIgnoredFiles: ["cache/one"]),
            isChecking: true
        )
        let finished = ArchiveRequest(
            workspace: workspace(),
            report: WorkspaceSafetyReport(modifiedIgnoredFiles: ["cache/one"])
        )

        #expect(reading.notes.isEmpty)
        #expect(!reading.message.contains("cache/one"))
        #expect(!finished.notes.isEmpty)
    }

    @Test("while it is checking the button still says what would be lost when something is known")
    func theButtonNamesALossItAlreadyKnows() {
        let reading = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isAgentMidTurn: true)
        )

        #expect(reading.isDestructive)
        #expect(reading.confirmLabel == "Archive anyway and lose that work")
    }

    @Test("a checking request says the branch goes unless the check finds commits only it holds")
    func theBranchIsAlreadyKnown() {
        let going = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isDeletingBranch: true)
        )
        let kept = ArchiveRequest.checking(workspace: workspace(), hazards: ArchiveHazards())

        #expect(going.message.contains(
            "the branch is deleted too, unless the check finds commits on it that exist nowhere else."
        ))
        #expect(kept.message.contains("kept"))
    }

    @Test("archive anyway keeps the branch when the report finds commits that exist nowhere else")
    func anywayKeepsABranchWithUnpublishedCommits() {
        let request = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isDeletingBranch: true)
        )

        #expect(request.deletesBranch(archivingWith: WorkspaceSafetyReport(unpushedCommits: 2)) == false)
    }

    @Test("archive anyway keeps the branch when no report arrived")
    func anywayKeepsTheBranchWithoutAReport() {
        let request = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isDeletingBranch: true)
        )

        #expect(request.deletesBranch(archivingWith: nil) == false)
    }

    @Test("archive anyway still deletes a branch the report clears")
    func anywayDeletesAClearedBranch() {
        let request = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isDeletingBranch: true)
        )
        let merged = ArchiveRequest.checking(
            workspace: workspace(),
            hazards: ArchiveHazards(isPullRequestMerged: true, isDeletingBranch: true)
        )

        #expect(request.deletesBranch(archivingWith: WorkspaceSafetyReport()))
        #expect(request.deletesBranch(archivingWith: WorkspaceSafetyReport(unpushedCommits: 1, isBranchMerged: true)))
        #expect(merged.deletesBranch(
            archivingWith: WorkspaceSafetyReport(unpushedCommits: 2, commitsAfterPullRequest: 0)
        ))
        #expect(merged.deletesBranch(
            archivingWith: WorkspaceSafetyReport(unpushedCommits: 2, commitsAfterPullRequest: 1)
        ) == false)
    }

    @Test("archive anyway never deletes a branch nobody asked to delete")
    func anywayKeepsAKeptBranch() {
        let request = ArchiveRequest.checking(workspace: workspace(), hazards: ArchiveHazards())

        #expect(request.deletesBranch(archivingWith: WorkspaceSafetyReport()) == false)
    }

    @Test("a confirmation given over a report deletes the branch it said it would")
    func aShownReportKeepsItsDecision() {
        let shown = ArchiveRequest(
            workspace: workspace(),
            report: WorkspaceSafetyReport(unpushedCommits: 2),
            hazards: ArchiveHazards(isDeletingBranch: true)
        )

        #expect(shown.deletesBranch(archivingWith: WorkspaceSafetyReport(unpushedCommits: 2)))
    }

    @Test("an agent mid turn is said at once, because the app knew that before it asked git anything")
    func theAgentIsSaidAtOnce() {
        let request = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isAgentMidTurn: true)
        )

        #expect(request.isDestructive)
        #expect(request.message.contains("not in git yet"))
    }

    @Test("a finished request claims nothing a checking one did not, except what it read")
    func theReportIsWhatChanges() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())
        let finished = ArchiveRequest(
            workspace: one,
            report: WorkspaceSafetyReport(hasUncommittedChanges: true),
            hazards: ArchiveHazards()
        )

        #expect(!finished.isChecking)
        #expect(finished.isDestructive)
        #expect(!finished.message.contains(ArchiveRequest.checkingSentence))
        #expect(checking.losses.isEmpty)
        #expect(!finished.losses.isEmpty)
    }

    @Test("two requests for the same workspace are the same popover, so replacing one does not reopen it")
    func oneWorkspaceIsOnePopover() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())
        let finished = ArchiveRequest(workspace: one, report: WorkspaceSafetyReport())

        #expect(checking.id == finished.id)
        #expect(checking.id == one.id)
    }

    @Test("requests for two workspaces are two popovers")
    func twoWorkspacesAreTwoPopovers() {
        let first = ArchiveRequest.checking(workspace: workspace("One"), hazards: ArchiveHazards())
        let second = ArchiveRequest.checking(workspace: workspace("Two"), hazards: ArchiveHazards())

        #expect(first.id != second.id)
    }
}
