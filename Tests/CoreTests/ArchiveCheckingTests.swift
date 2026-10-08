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
        let request = ArchiveRequest.checking(workspace: workspace(), hazards: ArchiveHazards())

        #expect(!request.isDestructive)
        #expect(request.severity == .worthMentioning)
    }

    @Test("a checking request lists no losses and no notes, because it has read nothing")
    func nothingIsClaimed() {
        let request = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isDeletingBranch: true)
        )

        #expect(request.losses.isEmpty)
        #expect(request.notes.isEmpty)
    }

    @Test("a checking request still says the branch is going, because that is already decided")
    func theBranchIsAlreadyKnown() {
        let going = ArchiveRequest.checking(
            workspace: workspace(), hazards: ArchiveHazards(isDeletingBranch: true)
        )
        let kept = ArchiveRequest.checking(workspace: workspace(), hazards: ArchiveHazards())

        #expect(going.message.contains("deleted too"))
        #expect(kept.message.contains("kept"))
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
