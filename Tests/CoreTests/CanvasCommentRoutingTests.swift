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

    @Test func routingIsNilWithNoChatAtAll() {
        #expect(CanvasCommentRouting.target(besideChat: nil, shownBy: nil, active: nil) == nil)
    }
}
