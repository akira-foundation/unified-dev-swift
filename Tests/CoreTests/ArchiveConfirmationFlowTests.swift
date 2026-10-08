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

    @Test("an offer shows when the screen is free")
    func anOfferShowsOnAFreeScreen() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        #expect(
            ArchiveConfirmationFlow.shows(
                .offer(checking), while: nil, replacesInPlace: true
            )?.isChecking == true
        )
    }

    @Test("an offer never pushes aside the question another workspace is waiting on")
    func anOfferYieldsToAnotherWorkspace() {
        let theirs = finished(workspace("Theirs"))
        let mine = ArchiveRequest.checking(workspace: workspace("Mine"), hazards: ArchiveHazards())

        #expect(
            ArchiveConfirmationFlow.shows(
                .offer(mine), while: theirs, replacesInPlace: true
            )?.id == theirs.id
        )
        #expect(
            ArchiveConfirmationFlow.shows(
                .offer(finished(workspace("Mine"))), while: theirs, replacesInPlace: true
            )?.id == theirs.id
        )
    }

    @Test("the report replaces the question it belongs to")
    func theReportReplacesItsOwn() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        let shown = ArchiveConfirmationFlow.shows(
            .replace(finished(one)), while: checking, replacesInPlace: true
        )

        #expect(shown?.id == one.id)
        #expect(shown?.isChecking == false)
    }

    @Test("the report of a question the owner already dismissed shows nothing")
    func aDismissedQuestionStaysDismissed() {
        #expect(
            ArchiveConfirmationFlow.shows(
                .replace(finished(workspace())), while: nil, replacesInPlace: true
            ) == nil
        )
    }

    @Test("the report of one workspace never pushes aside the question of another")
    func anotherWorkspaceIsUntouched() {
        let mine = workspace("Mine")
        let theirs = ArchiveRequest.checking(workspace: workspace("Theirs"), hazards: ArchiveHazards())

        let shown = ArchiveConfirmationFlow.shows(
            .replace(finished(mine)), while: theirs, replacesInPlace: true
        )

        #expect(shown?.id == theirs.id)
        #expect(shown?.isChecking == true)
    }

    @Test("with nothing left to ask, the question it belongs to goes")
    func withdrawingClosesItsOwn() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        #expect(
            ArchiveConfirmationFlow.shows(
                .withdraw(one.id), while: checking, replacesInPlace: true
            ) == nil
        )
    }

    @Test("withdrawing never closes another workspace's question")
    func withdrawingLeavesOthers() {
        let theirs = ArchiveRequest.checking(workspace: workspace("Theirs"), hazards: ArchiveHazards())

        #expect(
            ArchiveConfirmationFlow.shows(
                .withdraw(workspace("Mine").id), while: theirs, replacesInPlace: true
            )?.id == theirs.id
        )
    }

    @Test("a presenter that cannot replace in place is never shown the placeholder")
    func aModalNeverShowsThePlaceholder() {
        let one = workspace()
        let checking = ArchiveRequest.checking(workspace: one, hazards: ArchiveHazards())

        #expect(
            ArchiveConfirmationFlow.shows(
                .offer(checking), while: nil, replacesInPlace: false
            ) == nil
        )
        #expect(
            ArchiveConfirmationFlow.shows(
                .withdraw(one.id), while: nil, replacesInPlace: false
            ) == nil
        )
    }

    @Test("a presenter that never showed the placeholder still gets the real question")
    func aModalStillAsks() {
        let one = workspace()

        #expect(
            ArchiveConfirmationFlow.shows(
                .replace(finished(one)), while: nil, replacesInPlace: false
            )?.id == one.id
        )
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
