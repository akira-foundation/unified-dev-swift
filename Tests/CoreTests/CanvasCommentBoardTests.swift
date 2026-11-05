import Foundation
import Testing
@testable import Core

@Suite("CanvasCommentBoard")
struct CanvasCommentBoardTests {
    private let fixture = CanvasSessionFixture()

    private func comment(
        _ id: String = "c", _ state: CanvasComment.State = .queued, delivery: String? = nil,
        response: String? = nil, at time: TimeInterval = 0
    ) -> CanvasComment {
        CanvasComment(
            id: CanvasCommentID(id), anchor: CanvasPoint(x: 1, y: 2), text: "Bigger", state: state, response: response,
            deliveryID: delivery.map { DeliveryID($0) }, createdAt: Date(timeIntervalSince1970: time)
        )
    }

    private func document(_ comments: CanvasComment...) -> CanvasDocument {
        var document = fixture.session().document
        document.comments = comments
        return document
    }

    @Test func onlyAResolvedCommentLeavesTheMarks() {
        let doc = document(
            comment("q"), comment("w", .working), comment("u", .unanswered),
            comment("r", .resolved), comment("d", .declined, response: "No.")
        )
        let marks = CanvasCommentBoard.marks(in: doc, confirmed: [])
        #expect(marks.map(\.id.rawValue) == ["q", "w", "u", "d"])
    }

    @Test func aQueuedCommentWhoseRowIsNotConfirmedHasNoMarkYet() {
        let doc = document(comment("linked", delivery: "d1"), comment("other", delivery: "d2"), comment("no-chat"))
        let marks = CanvasCommentBoard.marks(in: doc, confirmed: [DeliveryID("d2")])
        #expect(marks.map(\.id.rawValue) == ["other", "no-chat"])
    }

    @Test func settlingThatFindsTheRowGoneMarksItUnansweredRatherThanQueued() throws {
        let doc = document(comment("gone", delivery: "d1"))
        let settled = CanvasCommentDelivery.settled(doc, inFlight: [], checked: [DeliveryID("d1")], live: [])
        let marks = CanvasCommentBoard.marks(in: settled, confirmed: [])
        #expect(try #require(marks.first).state == .unanswered)
    }

    @Test func aSettleForgetsARowItFoundGoneAndKeepsOneItDidNotCheck() {
        let confirmed = CanvasCommentBoard.confirmed(
            previously: [DeliveryID("gone"), DeliveryID("sent-meanwhile")],
            checked: [DeliveryID("gone"), DeliveryID("alive")],
            live: [DeliveryID("alive")]
        )
        #expect(confirmed == [DeliveryID("sent-meanwhile"), DeliveryID("alive")])
    }

    @Test func theListHoldsEveryCommentInTheOrderTheyWereLeft() {
        let doc = document(comment("late", .resolved, at: 9), comment("early", .declined, at: 1), comment("mid", at: 5))
        #expect(CanvasCommentBoard.listed(in: doc).map(\.id.rawValue) == ["early", "mid", "late"])
    }

    @Test(arguments: [
        CanvasCommentWait.cameWithFile, .documentHeld, .noChat, .stoppedByHand, .draftBeingEdited, .held(.question), .rewindInterrupted, .terminalChat,
    ])
    func aWaitTheOwnerCanEndSaysWhatToDo(wait: CanvasCommentWait) {
        let status = CanvasCommentBoard.status(of: comment(delivery: "d"), wait: wait)
        #expect(status.needsOwner)
        #expect(!status.detail.isEmpty)
    }

    @Test(arguments: [
        CanvasCommentWait.held(.setup), .held(.turn), .archiving, .savingTurn, .messageAhead, .commentAhead, .nextInLine,
    ])
    func aWaitThatEndsByItselfAsksNothingOfTheOwner(wait: CanvasCommentWait) {
        #expect(!CanvasCommentBoard.status(of: comment(delivery: "d"), wait: wait).needsOwner)
    }

    @Test func theWordsNameWhatToDo() {
        let noChat = CanvasCommentBoard.status(of: comment(), wait: .noChat)
        let stopped = CanvasCommentBoard.status(of: comment(delivery: "d"), wait: .stoppedByHand)
        let draft = CanvasCommentBoard.status(of: comment(delivery: "d"), wait: .draftBeingEdited)
        let question = CanvasCommentBoard.status(of: comment(delivery: "d"), wait: .held(.question))
        #expect(noChat.detail.contains("Start a chat"))
        #expect(stopped.detail.contains("Send it a message"))
        #expect(draft.detail.contains("composer"))
        #expect(question.detail.contains("Answer"))
    }

    @Test func theStatesReadInWords() {
        #expect(CanvasCommentBoard.status(of: comment(), wait: nil).title == "Queued")
        #expect(CanvasCommentBoard.status(of: comment("w", .working), wait: nil).title == "Being handled")
        let unanswered = CanvasCommentBoard.status(of: comment("u", .unanswered), wait: nil)
        #expect(unanswered.title == "Unanswered")
        #expect(unanswered.needsOwner)
        #expect(CanvasCommentBoard.status(of: comment("r", .resolved), wait: nil).title == "Resolved")
        #expect(CanvasCommentBoard.status(of: comment("d", .declined), wait: nil).title == "Declined")
    }

    @Test func theResponseIsAnAnswerOrAReason() {
        #expect(CanvasCommentBoard.responseLabel(of: comment("r", .resolved, response: "Done")) == "Answer")
        #expect(CanvasCommentBoard.responseLabel(of: comment("d", .declined, response: "No")) == "Reason")
        #expect(CanvasCommentBoard.responseLabel(of: comment("q", response: "stale")) == nil)
        #expect(CanvasCommentBoard.responseLabel(of: comment("r", .resolved)) == nil)
    }

    @Test func whatTheOwnerMayDoFollowsTheState() {
        #expect(CanvasCommentBoard.canEdit(comment()))
        #expect(!CanvasCommentBoard.canEdit(comment("w", .working)))
        #expect(!CanvasCommentBoard.canEdit(comment("u", .unanswered)))
        #expect(CanvasCommentBoard.canResend(comment("u", .unanswered)))
        #expect(!CanvasCommentBoard.canResend(comment()))
        #expect(!CanvasCommentBoard.canDelete(comment("w", .working)))
        for state in [CanvasComment.State.queued, .unanswered, .resolved, .declined] {
            #expect(CanvasCommentBoard.canDelete(comment("x", state)))
        }
    }

    @Test func aCommentPlacedOnASlideNamesTheFrameAndTheElementUnderIt() throws {
        let doc = fixture.session().document
        let made = try #require(CanvasCommentFlow.placed(
            text: "  Bigger \n", at: CanvasPoint(x: 8, y: 8), in: doc, createdAt: Date(timeIntervalSince1970: 3)
        ))
        #expect(made.text == "Bigger")
        #expect(made.frameID == fixture.frameID)
        #expect(made.elementID == fixture.boxID)
        #expect(made.state == .queued)
        #expect(made.deliveryID == nil)
    }

    @Test func aCommentOffEverySlideNamesNothing() throws {
        let made = try #require(CanvasCommentFlow.placed(
            text: "Here", at: CanvasPoint(x: 900, y: 900), in: fixture.session().document, createdAt: Date()
        ))
        #expect(made.frameID == nil)
        #expect(made.elementID == nil)
    }

    @Test func aBlankCommentIsNotPlaced() {
        let made = CanvasCommentFlow.placed(
            text: " \n ", at: CanvasPoint(x: 1, y: 1), in: fixture.session().document, createdAt: Date()
        )
        #expect(made == nil)
    }

    @Test func editingAQueuedCommentChangesItsTextAndDropsTheCancelledLink() throws {
        let doc = document(comment("q", delivery: "d1"))
        let edited = CanvasCommentFlow.edited(CanvasCommentID("q"), text: " Smaller ", in: doc)
        let only = try #require(edited.comments.first)
        #expect(only.text == "Smaller")
        #expect(only.deliveryID == nil)
        #expect(only.state == .queued)
    }

    @Test(arguments: [CanvasComment.State.working, .resolved, .declined])
    func aCommentThatLeftForGoodIsNotRewritten(state: CanvasComment.State) {
        let doc = document(comment("x", state, delivery: "d1"))
        #expect(CanvasCommentFlow.edited(CanvasCommentID("x"), text: "Smaller", in: doc) == doc)
    }

    @Test func aBlankEditChangesNothing() {
        let doc = document(comment("q", delivery: "d1"))
        #expect(CanvasCommentFlow.edited(CanvasCommentID("q"), text: "  ", in: doc) == doc)
    }

    @Test func removingLeavesTheRestAndNeverTakesOneBeingHandled() {
        let doc = document(comment("q"), comment("w", .working))
        #expect(CanvasCommentFlow.removed(CanvasCommentID("q"), in: doc).comments.map(\.id.rawValue) == ["w"])
        #expect(CanvasCommentFlow.removed(CanvasCommentID("w"), in: doc) == doc)
    }
}
