import Foundation
import Testing
@testable import Core

@Suite("CanvasCommentDelivery")
struct CanvasCommentDeliveryDecisionTests {
    private let fixture = CanvasSessionFixture()
    private let path = "/work/deck.udcanvas"
    private let linked = DeliveryID("d1")

    private func comment(
        _ state: CanvasComment.State = .queued, delivery: DeliveryID? = DeliveryID("d1"), text: String = "Bigger"
    ) -> CanvasComment {
        CanvasComment(
            id: CanvasCommentID("c1"), anchor: CanvasPoint(x: 12, y: 34), text: text, state: state,
            deliveryID: delivery, createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func document(_ comments: CanvasComment...) -> CanvasDocument {
        var document = fixture.session().document
        document.comments = comments
        return document
    }

    private func row(state: Delivery.State = .pending, body: String = "old") -> Delivery {
        Delivery(
            id: linked, targetSessionID: SessionID("s"), kind: .canvasComment, body: body, state: state,
            canvasDocumentPath: path
        )
    }

    @Test func aNewDeliveryCarriesTheDocumentAndTheMessage() {
        let note = comment(delivery: nil)
        let doc = document(note)
        let made = CanvasCommentDelivery.delivery(
            for: note, path: path, in: doc, to: SessionID("s"), createdAt: Date(timeIntervalSince1970: 5)
        )
        #expect(made.kind == .canvasComment)
        #expect(made.canvasDocumentPath == path)
        #expect(made.targetSessionID == SessionID("s"))
        #expect(made.body == CanvasCommentFlow.message(for: note, path: path, in: doc))
        #expect(made.interactionMode == nil)
        #expect(made.crewPayload == nil)
    }

    @Test func aCommentEditedAfterQueueingSendsWhatItSaysNow() {
        let edited = comment(text: "Smaller")
        let doc = document(edited)
        let decision = CanvasCommentDelivery.decide(row(), in: .document(doc))
        #expect(decision == .send(CanvasCommentFlow.message(for: edited, path: path, in: doc)))
    }

    @Test func aDeletedCommentDropsItsDelivery() {
        #expect(CanvasCommentDelivery.decide(row(), in: .document(document())) == .drop)
    }

    @Test func aCommentGivenAnotherDeliveryDropsTheOldOne() {
        let doc = document(comment(delivery: DeliveryID("d2")))
        #expect(CanvasCommentDelivery.decide(row(), in: .document(doc)) == .drop)
    }

    @Test(arguments: [CanvasComment.State.resolved, .declined])
    func aCommentAlreadyDealtWithDropsItsDelivery(state: CanvasComment.State) {
        #expect(CanvasCommentDelivery.decide(row(), in: .document(document(comment(state)))) == .drop)
    }

    @Test(arguments: [CanvasComment.State.queued, .unanswered, .working])
    func aCommentStillOwedAnAnswerGoes(state: CanvasComment.State) {
        let doc = document(comment(state))
        guard case .send = CanvasCommentDelivery.decide(row(), in: .document(doc)) else {
            Issue.record("\(state) did not go")
            return
        }
    }

    @Test func aDocumentThatCannotBeReadDropsItsDelivery() {
        #expect(CanvasCommentDelivery.decide(row(), in: nil) == .drop)
        #expect(CanvasCommentDelivery.decide(row(), in: .corrupt("bad")) == .drop)
        #expect(CanvasCommentDelivery.decide(row(), in: .newerVersion(99)) == .drop)
    }

    @Test func aDeliveryThatMayAlreadyHaveGoneIsNotSentAgain() {
        let doc = document(comment())
        #expect(CanvasCommentDelivery.decide(row(state: .uncertain), in: .document(doc)) == .drop)
    }

    @Test func aDeliveryThatNamesNoDocumentIsDropped() {
        var nameless = row()
        nameless.canvasDocumentPath = nil
        #expect(CanvasCommentDelivery.decide(nameless, in: .document(document(comment()))) == .drop)
    }

    @Test func thePathMustStayInsideThisWorktree() {
        var inside = row()
        inside.canvasDocumentPath = "/work/deck.udcanvas"
        var outside = row()
        outside.canvasDocumentPath = "/elsewhere/deck.udcanvas"
        var wrongType = row()
        wrongType.canvasDocumentPath = "/work/deck.html"
        var nameless = row()
        nameless.canvasDocumentPath = nil
        #expect(CanvasCommentDelivery.documentPath(of: inside, worktree: "/work") == "/work/deck.udcanvas")
        #expect(CanvasCommentDelivery.documentPath(of: outside, worktree: "/work") == nil)
        #expect(CanvasCommentDelivery.documentPath(of: wrongType, worktree: "/work") == nil)
        #expect(CanvasCommentDelivery.documentPath(of: nameless, worktree: "/work") == nil)
    }

    @Test(arguments: [CanvasComment.State.queued, .unanswered])
    func startingFindsTheCommentByItsDelivery(state: CanvasComment.State) {
        var other = comment(delivery: DeliveryID("d2"))
        other.id = CanvasCommentID("c2")
        let started = CanvasCommentDelivery.started(linked, in: document(comment(state), other))
        #expect(started.comments.map(\.state) == [.working, .queued])
    }

    @Test func aCommentResolvedBeforeItsTurnStartedStaysResolved() {
        let started = CanvasCommentDelivery.started(linked, in: document(comment(.resolved)))
        #expect(started.comments.first?.state == .resolved)
    }

    @Test(arguments: [CanvasComment.State.working, .unanswered, .queued])
    func notSentAndStillQueuedGoesBackToTheQueue(state: CanvasComment.State) {
        let back = CanvasCommentDelivery.notSent(linked, stillQueued: true, in: document(comment(state)))
        #expect(back.comments.first?.state == .queued)
    }

    @Test(arguments: [CanvasComment.State.working, .unanswered, .queued])
    func notSentAndGoneFromTheQueueIsOwedAnAnswer(state: CanvasComment.State) {
        let gone = CanvasCommentDelivery.notSent(linked, stillQueued: false, in: document(comment(state)))
        #expect(gone.comments.first?.state == .unanswered)
    }

    @Test(arguments: [CanvasComment.State.resolved, .declined])
    func notSentLeavesACommentAlreadyDealtWith(state: CanvasComment.State) {
        let kept = CanvasCommentDelivery.notSent(linked, stillQueued: false, in: document(comment(state)))
        #expect(kept.comments.first?.state == state)
    }

    @Test func notSentLeavesAnotherDeliverysComment() {
        let other = comment(.working, delivery: DeliveryID("d2"))
        let kept = CanvasCommentDelivery.notSent(linked, stillQueued: false, in: document(other))
        #expect(kept.comments.first?.state == .working)
    }

    @Test func assigningQueuesTheCommentUnderItsDelivery() {
        let note = comment(.unanswered, delivery: DeliveryID("old"))
        let assigned = CanvasCommentDelivery.assigned(note.id, to: linked, in: document(note))
        #expect(assigned.comments.first?.state == .queued)
        #expect(assigned.comments.first?.deliveryID == linked)
    }

    @Test func aCommentWithNoChatIsTheOneAwaitingAChat() {
        let waiting = comment(delivery: nil)
        var routed = comment()
        routed.id = CanvasCommentID("c2")
        var unanswered = comment(.unanswered, delivery: nil)
        unanswered.id = CanvasCommentID("c3")
        let awaiting = CanvasCommentDelivery.awaitingChat(in: document(waiting, routed, unanswered))
        #expect(awaiting.map(\.id) == [waiting.id])
    }

    @Test func settlingEndsAWorkingCommentNoTurnHolds() {
        let settled = CanvasCommentDelivery.settled(
            document(comment(.working)), inFlight: [], checked: [], live: []
        )
        #expect(settled.comments.first?.state == .unanswered)
    }

    @Test func settlingLeavesTheCommentATurnHolds() {
        let settled = CanvasCommentDelivery.settled(
            document(comment(.working)), inFlight: [linked], checked: [], live: []
        )
        #expect(settled.comments.first?.state == .working)
    }

    @Test func settlingEndsAQueuedCommentWhoseRowIsConsumed() {
        let settled = CanvasCommentDelivery.settled(
            document(comment()), inFlight: [], checked: [linked], live: []
        )
        #expect(settled.comments.first?.state == .unanswered)
    }

    @Test func settlingLeavesAQueuedCommentWhoseRowIsLive() {
        let settled = CanvasCommentDelivery.settled(
            document(comment()), inFlight: [], checked: [linked], live: [linked]
        )
        #expect(settled.comments.first?.state == .queued)
    }

    @Test func settlingDoesNotJudgeARowItNeverLookedAt() {
        let settled = CanvasCommentDelivery.settled(
            document(comment()), inFlight: [], checked: [], live: []
        )
        #expect(settled.comments.first?.state == .queued)
    }

    @Test func settlingLeavesACommentWaitingForAChat() {
        let settled = CanvasCommentDelivery.settled(
            document(comment(delivery: nil)), inFlight: [], checked: [linked], live: []
        )
        #expect(settled.comments.first?.state == .queued)
    }

    @Test func onlyQueuedCommentsWithARowNeedLookingUp() {
        var noRow = comment(delivery: nil)
        noRow.id = CanvasCommentID("c2")
        var answered = comment(.resolved, delivery: DeliveryID("d3"))
        answered.id = CanvasCommentID("c3")
        #expect(CanvasCommentDelivery.deliveriesToCheck(in: document(comment(), noRow, answered)) == [linked])
    }
}
