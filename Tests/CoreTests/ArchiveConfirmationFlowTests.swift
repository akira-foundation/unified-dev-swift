import Foundation
import Testing
@testable import Core

@Suite("What replaces the question already on screen")
struct ArchiveConfirmationFlowTests {
    private func workspace(_ name: String = "Lighthouse") -> Workspace {
        Workspace(
            repoID: RepoID.new(), name: name, branch: "lighthouse",
            path: "/tmp/\(name)", baseBranch: "main"
        )
    }

    private func finished(_ workspace: Workspace) -> ArchiveRequest {
        ArchiveRequest(
            workspace: workspace, report: WorkspaceSafetyReport(hasUncommittedChanges: true)
        )
    }

    @Test("an offer shows, whatever was there")
    func anOfferAlwaysShows() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        #expect(ArchiveConfirmationFlow.shows(.offer(checking), while: nil)?.isChecking == true)
        #expect(
            ArchiveConfirmationFlow.shows(.offer(checking), while: finished(workspace("Other")))?.id == one.id
        )
    }

    @Test("the report replaces the question it belongs to")
    func theReportReplacesItsOwn() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        let shown = ArchiveConfirmationFlow.shows(.replace(finished(one)), while: checking)

        #expect(shown?.id == one.id)
        #expect(shown?.isChecking == false)
    }

    @Test("the report of a question the owner already dismissed shows nothing")
    func aDismissedQuestionStaysDismissed() {
        #expect(ArchiveConfirmationFlow.shows(.replace(finished(workspace())), while: nil) == nil)
    }

    @Test("the report of one workspace never pushes aside the question of another")
    func anotherWorkspaceIsUntouched() {
        let mine = workspace("Mine")
        let theirs = ArchiveRequest.checking(workspace: workspace("Theirs"), hazards: ArchiveHazards())

        let shown = ArchiveConfirmationFlow.shows(.replace(finished(mine)), while: theirs)

        #expect(shown?.id == theirs.id)
        #expect(shown?.isChecking == true)
    }

    @Test("with nothing left to ask, the question it belongs to goes")
    func withdrawingClosesItsOwn() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        #expect(ArchiveConfirmationFlow.shows(.withdraw(one.id), while: checking) == nil)
    }

    @Test("withdrawing never closes another workspace's question")
    func withdrawingLeavesOthers() {
        let theirs = ArchiveRequest.checking(workspace: workspace("Theirs"), hazards: ArchiveHazards())

        #expect(ArchiveConfirmationFlow.shows(.withdraw(workspace("Mine").id), while: theirs)?.id == theirs.id)
    }

    @Test("every update carries the request the view is handed, and withdrawing carries none")
    func theRequestAnUpdateCarries() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        #expect(ArchiveConfirmationFlow.Update.offer(checking).request?.id == one.id)
        #expect(ArchiveConfirmationFlow.Update.replace(finished(one)).request?.isChecking == false)
        #expect(ArchiveConfirmationFlow.Update.withdraw(one.id).request == nil)
    }
}
