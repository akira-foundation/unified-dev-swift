import Testing
import Foundation
@testable import Core

@Suite("Being at the end of a scroll")
struct ScrollEndTests {
    @Test("content that fits in the pane is at its end, wherever the offset says it is")
    func contentShorterThanTheViewport() {
        #expect(ScrollEnd.isAtEnd(contentHeight: 400, viewportHeight: 820, offset: 0))
        #expect(ScrollEnd.isAtEnd(contentHeight: 400, viewportHeight: 820, offset: -52))
        #expect(ScrollEnd.isAtEnd(contentHeight: 820, viewportHeight: 820, offset: 0))
    }

    @Test("a pane with no height has not been scrolled away from")
    func viewportWithNoHeight() {
        #expect(ScrollEnd.isAtEnd(contentHeight: 4000, viewportHeight: 0, offset: 0))
        #expect(ScrollEnd.isAtEnd(contentHeight: 4000, viewportHeight: -1, offset: 0))
    }

    @Test("content taller than the pane is at its end only near the bottom of it")
    func contentTallerThanTheViewport() {
        #expect(ScrollEnd.isAtEnd(contentHeight: 4000, viewportHeight: 800, offset: 3200))
        #expect(ScrollEnd.isAtEnd(contentHeight: 4000, viewportHeight: 800, offset: 3150))
        #expect(!ScrollEnd.isAtEnd(contentHeight: 4000, viewportHeight: 800, offset: 2800))
        #expect(!ScrollEnd.isAtEnd(contentHeight: 4000, viewportHeight: 800, offset: 0))
    }

    @Test("the threshold is where it says it is")
    func thresholdBoundary() {
        let content = 4000.0, viewport = 800.0
        let atEnd = content - viewport
        #expect(ScrollEnd.isAtEnd(
            contentHeight: content, viewportHeight: viewport, offset: atEnd - 95
        ))
        #expect(!ScrollEnd.isAtEnd(
            contentHeight: content, viewportHeight: viewport, offset: atEnd - 96
        ))
    }

    @Test("a queued message that fits in the pane does not put the reader away from the end")
    func pendingBubblesDoNotMoveTheEnd() {
        #expect(ScrollEnd.isAtEnd(contentHeight: 500, viewportHeight: 820, offset: 0))
        #expect(!ScrollEnd.isAtEnd(contentHeight: 1200, viewportHeight: 820, offset: 0))
    }
}

@Suite("Offering the way back")
struct ScrollEndOfferTests {
    private func offers(offset: Double, content: Double = 4_000, viewport: Double = 800) -> Bool {
        ScrollEnd.isWorthOffering(
            contentHeight: content, viewportHeight: viewport, offset: offset
        )
    }

    @Test("a line or two of scrolling is not worth an offer")
    func aNudgeOffersNothing() {
        #expect(!offers(offset: 3_200))
        #expect(!offers(offset: 3_104))
    }

    @Test("a screen and a half away is")
    func screensAwayOffers() {
        #expect(!offers(offset: 2_100))
        #expect(offers(offset: 1_900))
        #expect(offers(offset: 0))
    }

    @Test("the distance is measured in screens, not points")
    func theDistanceScalesWithTheWindow() {
        #expect(offers(offset: 2_300, content: 4_000, viewport: 500) == true)
        #expect(offers(offset: 2_300, content: 4_000, viewport: 800) == false)
    }

    @Test("a pane with nothing to scroll never offers")
    func nothingToScrollOffersNothing() {
        #expect(!ScrollEnd.isWorthOffering(contentHeight: 4_000, viewportHeight: 0, offset: 0))
        #expect(!ScrollEnd.isWorthOffering(contentHeight: 300, viewportHeight: 800, offset: 0))
    }

    @Test("still following along and worth offering are different answers")
    func theTwoQuestionsDisagreeOnPurpose() {
        let content = 4_000.0, viewport = 800.0, offset = 2_800.0
        #expect(!ScrollEnd.isAtEnd(
            contentHeight: content, viewportHeight: viewport, offset: offset
        ))
        #expect(!ScrollEnd.isWorthOffering(
            contentHeight: content, viewportHeight: viewport, offset: offset
        ))
    }
}
