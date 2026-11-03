import Testing
@testable import Core

@Suite("CanvasCommentRouting")
struct CanvasCommentRoutingTests {
    private let beside = SessionID("beside")
    private let shown = SessionID("shown")
    private let active = SessionID("active")

    @Test func routingPrefersBeside() {
        #expect(CanvasCommentRouting.target(besideChat: beside, shownBy: shown, active: active) == beside)
    }

    @Test func routingFallsBackToTheChatThatShowedIt() {
        #expect(CanvasCommentRouting.target(besideChat: nil, shownBy: shown, active: active) == shown)
    }

    @Test func routingFallsBackToTheActiveChat() {
        #expect(CanvasCommentRouting.target(besideChat: nil, shownBy: nil, active: active) == active)
    }

    @Test func aStaleCandidateFallsThroughToTheNext() {
        let shownOnly = CanvasCommentRouting.target(besideChat: beside, shownBy: shown, active: active) { $0 == shown }
        let activeOnly = CanvasCommentRouting.target(besideChat: beside, shownBy: shown, active: active) { $0 == active }
        let none = CanvasCommentRouting.target(besideChat: beside, shownBy: shown, active: active) { _ in false }
        #expect(shownOnly == shown)
        #expect(activeOnly == active)
        #expect(none == nil)
    }

    @Test func routingIsNilWithNoChatAtAll() {
        #expect(CanvasCommentRouting.target(besideChat: nil, shownBy: nil, active: nil) == nil)
    }
}
