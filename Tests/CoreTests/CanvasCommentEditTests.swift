import Foundation
import Testing
@testable import Core

@Suite("Changing a comment the queue may already have sent")
struct CanvasCommentEditTests {
    private let id = CanvasCommentID("c")
    private let row = DeliveryID("d1")

    private func document(_ state: CanvasComment.State = .queued, delivery: DeliveryID? = DeliveryID("d1"), text: String = "Old") -> CanvasDocument {
        CanvasDocument(comments: [CanvasComment(
            id: id, anchor: CanvasPoint(x: 1, y: 1), text: text, state: state, deliveryID: delivery,
            createdAt: Date(timeIntervalSince1970: 0)
        )])
    }

    private func delivery(_ state: Delivery.State) -> Delivery {
        Delivery(id: row, targetSessionID: SessionID("s"), kind: .canvasComment, body: "x", state: state)
    }

    @Test func aQueuedCommentCancelsItsRowFirst() {
        #expect(CanvasCommentEdit.beginEdit(id, text: "New", in: document()) == .cancel(row))
        #expect(CanvasCommentEdit.beginEdit(id, text: "New", in: document(delivery: nil)) == .cancel(nil))
    }

    @Test func theSameTextChangesNothingAndCancelsNothing() {
        #expect(CanvasCommentEdit.beginEdit(id, text: " Old\n", in: document()) == .finished(.unchanged))
    }

    @Test(arguments: [CanvasComment.State.working, .unanswered, .resolved, .declined])
    func aCommentThatLeftBeforeTheSaveIsToldSo(state: CanvasComment.State) {
        #expect(CanvasCommentEdit.beginEdit(id, text: "New", in: document(state)) == .finished(.alreadyLeft))
    }

    @Test func aCommentThatIsGoneOrABlankTextIsNotEditable() {
        #expect(CanvasCommentEdit.beginEdit(CanvasCommentID("other"), text: "New", in: document()) == .finished(.notEditable))
        #expect(CanvasCommentEdit.beginEdit(id, text: "  ", in: document()) == .finished(.notEditable))
    }

    @Test func aCancelledRowAppliesTheTextAndClearsTheLink() throws {
        let outcome = CanvasCommentEdit.concludeEdit(id, text: "New", answer: .removed, in: document())
        guard case .changed(let changed) = outcome else {
            Issue.record("not changed: \(outcome)")
            return
        }
        let comment = try #require(changed.comments.first)
        #expect(comment.text == "New")
        #expect(comment.deliveryID == nil)
        #expect(comment.state == .queued)
    }

    @Test func aSettleThatTurnedItUnansweredDuringTheCancelDoesNotLoseTheEdit() throws {
        let outcome = CanvasCommentEdit.concludeEdit(id, text: "New", answer: .removed, in: document(.unanswered))
        guard case .changed(let changed) = outcome else {
            Issue.record("not changed: \(outcome)")
            return
        }
        let comment = try #require(changed.comments.first)
        #expect(comment.text == "New")
        #expect(comment.state == .queued)
        #expect(comment.deliveryID == nil)
    }

    @Test(arguments: [CanvasCommentCancelAnswer.rowFinished, .rowInFlight])
    func aCancelThatLostTheRaceRefusesTheEdit(answer: CanvasCommentCancelAnswer) {
        #expect(CanvasCommentEdit.concludeEdit(id, text: "New", answer: answer, in: document()) == .alreadyLeft)
    }

    @Test(arguments: [CanvasComment.State.working, .resolved, .declined])
    func aCommentTheAgentTookDuringTheCancelIsNotRewritten(state: CanvasComment.State) {
        #expect(CanvasCommentEdit.concludeEdit(id, text: "New", answer: .removed, in: document(state)) == .alreadyLeft)
    }

    @Test func aDatabaseErrorSaysWhatHappenedAndNotThatItLeft() throws {
        let outcome = CanvasCommentEdit.concludeEdit(id, text: "New", answer: .failed("disk full"), in: document())
        #expect(outcome == .couldNotCheck("disk full"))
        let sentence = try #require(outcome.sentence)
        #expect(sentence.contains("disk full"))
        #expect(!sentence.contains("already gone"))
    }

    @Test(arguments: [
        CanvasCommentChangeOutcome.alreadyLeft, .notEditable, .couldNotCheck("x"),
    ])
    func everyRefusalHasAWord(outcome: CanvasCommentChangeOutcome) {
        #expect(outcome.sentence?.isEmpty == false)
    }

    @Test func whatChangedOrDidNotNeedChangingHasNoWord() {
        #expect(CanvasCommentChangeOutcome.unchanged.sentence == nil)
        #expect(CanvasCommentChangeOutcome.changed(document()).sentence == nil)
    }

    @Test func aRefusedCancelIsReadFromTheRow() {
        #expect(CanvasCommentCancelAnswer.afterRefusal(row: nil) == .removed)
        #expect(CanvasCommentCancelAnswer.afterRefusal(row: delivery(.accepted)) == .rowFinished)
        #expect(CanvasCommentCancelAnswer.afterRefusal(row: delivery(.claimed)) == .rowInFlight)
    }

    @Test func aResendCancelsTheOldRow() {
        #expect(CanvasCommentEdit.beginResend(id, in: document(.unanswered)) == .cancel(row))
    }

    @Test(arguments: [CanvasComment.State.queued, .working, .resolved, .declined])
    func onlyAnUnansweredCommentIsResent(state: CanvasComment.State) {
        #expect(CanvasCommentEdit.beginResend(id, in: document(state)) == .finished(.notEditable))
    }

    @Test func aResendStopsWhenTheOldRowIsStillGoing() {
        #expect(CanvasCommentEdit.concludeResend(id, answer: .rowInFlight, in: document(.unanswered)) == .alreadyLeft)
        #expect(CanvasCommentEdit.concludeResend(id, answer: .failed("x"), in: document(.unanswered)) == .couldNotCheck("x"))
    }

    @Test(arguments: [CanvasCommentCancelAnswer.removed, .rowFinished])
    func aResendGoesOnceNoOldRowCanGo(answer: CanvasCommentCancelAnswer) throws {
        let outcome = CanvasCommentEdit.concludeResend(id, answer: answer, in: document(.unanswered))
        guard case .changed(let changed) = outcome else {
            Issue.record("not changed: \(outcome)")
            return
        }
        #expect(try #require(changed.comments.first).deliveryID == nil)
    }

    @Test func aResendAnsweredMeanwhileIsNotSent() {
        #expect(CanvasCommentEdit.concludeResend(id, answer: .removed, in: document(.resolved)) == .notEditable)
    }

    @Test func aQueuedCommentIsDeletedOnlyOnceItsRowIsCancelled() {
        #expect(CanvasCommentEdit.beginDelete(id, in: document()) == .cancel(row))
        #expect(CanvasCommentEdit.concludeDelete(id, answer: .rowInFlight, in: document()) == .alreadyLeft)
        #expect(CanvasCommentEdit.concludeDelete(id, answer: .failed("x"), in: document()) == .couldNotCheck("x"))
        guard case .changed(let changed) = CanvasCommentEdit.concludeDelete(id, answer: .removed, in: document()) else {
            Issue.record("not deleted")
            return
        }
        #expect(changed.comments.isEmpty)
    }

    @Test(arguments: [CanvasComment.State.unanswered, .resolved, .declined])
    func anAnsweredOrUnansweredCommentIsDeletedWithoutAskingTheQueue(state: CanvasComment.State) {
        #expect(CanvasCommentEdit.beginDelete(id, in: document(state)) == .cancel(nil))
    }

    @Test func aCommentBeingHandledIsNotDeleted() {
        #expect(CanvasCommentEdit.beginDelete(id, in: document(.working)) == .finished(.alreadyLeft))
    }
}
