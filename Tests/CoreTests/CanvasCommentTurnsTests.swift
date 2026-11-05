import Foundation
import Testing
@testable import Core

@Suite("CanvasCommentTurns")
struct CanvasCommentTurnsTests {
    private let sessionA = SessionID("a")
    private let sessionB = SessionID("b")

    private func turn(_ delivery: String, path: String = "/w/deck.udcanvas") -> CanvasCommentTurn {
        CanvasCommentTurn(deliveryID: DeliveryID(delivery), path: path)
    }

    @Test func aTurnEndingInOneChatAnswersOnlyForThatChat() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("da"), in: sessionA)
        _ = turns.start(turn("db"), in: sessionB)
        turns.began(DeliveryID("da"), in: sessionA)

        let ended = turns.end(in: sessionA)

        #expect(ended == turn("da"))
        #expect(turns.deliveries(inDocument: "/w/deck.udcanvas") == [DeliveryID("db")])
    }

    @Test func aChatWithNoCommentInItsTurnEndsNothing() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("db"), in: sessionB)
        let ended = turns.end(in: sessionA)
        #expect(ended == nil)
        #expect(turns.deliveries(inDocument: "/w/deck.udcanvas") == [DeliveryID("db")])
    }

    @Test func aTurnEndsOnce() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("da"), in: sessionA)
        turns.began(DeliveryID("da"), in: sessionA)
        _ = turns.end(in: sessionA)
        let again = turns.end(in: sessionA)
        #expect(again == nil)
    }

    @Test func startingOverAnUnfinishedTurnHandsItBackToBeEnded() {
        var turns = CanvasCommentTurns()
        let first = turns.start(turn("first"), in: sessionA)
        let displaced = turns.start(turn("second"), in: sessionA)
        #expect(first == nil)
        #expect(displaced == turn("first"))
        #expect(turns.deliveries(inDocument: "/w/deck.udcanvas") == [DeliveryID("second")])
    }

    @Test func droppingAQueuedCommentLeavesTheCommentTheChatIsWorking() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("working"), in: sessionA)
        turns.end(DeliveryID("queued"), in: sessionA)
        #expect(turns.deliveries(inDocument: "/w/deck.udcanvas") == [DeliveryID("working")])
        turns.end(DeliveryID("working"), in: sessionA)
        #expect(turns.deliveries(inDocument: "/w/deck.udcanvas").isEmpty)
    }

    @Test func theLastTurnEndingLeavesACommentStillStartingAlone() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("next"), in: sessionA)

        let ended = turns.end(in: sessionA)

        #expect(ended == nil)
        #expect(turns.deliveries(inDocument: "/w/deck.udcanvas") == [DeliveryID("next")])
    }

    @Test func aCommentThatBeganEndsWithItsTurn() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("next"), in: sessionA)
        turns.began(DeliveryID("next"), in: sessionA)

        let ended = turns.end(in: sessionA)

        #expect(ended == turn("next"))
    }

    @Test func beginningAnotherDeliveryLeavesTheStartingCommentStarting() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("next"), in: sessionA)
        turns.began(DeliveryID("other"), in: sessionA)

        let ended = turns.end(in: sessionA)

        #expect(ended == nil)
    }

    @Test func aStopEndsACommentStillStarting() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("next"), in: sessionA)

        let stopped = turns.stop(in: sessionA)

        #expect(stopped == turn("next"))
        #expect(turns.deliveries(inDocument: "/w/deck.udcanvas").isEmpty)
    }

    @Test func aCommentThatCouldNotBeSentIsNoLongerStarting() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("next"), in: sessionA)
        turns.end(DeliveryID("next"), in: sessionA)
        _ = turns.start(turn("after"), in: sessionA)
        turns.began(DeliveryID("after"), in: sessionA)

        #expect(turns.end(in: sessionA) == turn("after"))
    }

    @Test func deliveriesAreCountedPerDocument() {
        var turns = CanvasCommentTurns()
        _ = turns.start(turn("da", path: "/w/one.udcanvas"), in: sessionA)
        _ = turns.start(turn("db", path: "/w/two.udcanvas"), in: sessionB)
        #expect(turns.deliveries(inDocument: "/w/one.udcanvas") == [DeliveryID("da")])
    }
}
