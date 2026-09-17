import Testing
@testable import Core

@Suite("The review pane's composer")
struct ReviewComposerTests {
    private let chat = SessionID("session-1")
    private let review = PaneContent.tool("review-tab")

    @Test func staysAwayFromAChatInTheSameTab() {
        #expect(!ReviewComposer.isDrawn(
            destination: chat, panes: [.chat(chat), review]
        ))
    }

    @Test func drawnWhenTheReviewIsAloneInItsTab() {
        #expect(ReviewComposer.isDrawn(destination: chat, panes: [review]))
    }

    @Test func drawnBesideAnotherReview() {
        #expect(ReviewComposer.isDrawn(
            destination: chat, panes: [review, .tool("review-tab-2")]
        ))
    }

    @Test func drawnWhenTheChatIsInAnotherTab() {
        let panes = [review]
        #expect(!panes.contains(.chat(chat)))
        #expect(ReviewComposer.isDrawn(destination: chat, panes: panes))
    }

    @Test func drawnBesideAChatItDoesNotSendTo() {
        #expect(ReviewComposer.isDrawn(
            destination: chat, panes: [.chat(SessionID("session-2")), review]
        ))
    }

    @Test func notDrawnWithoutASession() {
        #expect(!ReviewComposer.isDrawn(destination: nil, panes: [review]))
    }
}
