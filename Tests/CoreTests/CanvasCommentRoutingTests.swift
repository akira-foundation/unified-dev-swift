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

    private func tab(root: PaneContent, _ contents: [String: PaneContent]) -> PaneSplitAnchor.Tab {
        var layout = SplitLayout(pane: "a")
        for pane in contents.keys.sorted() where pane != "a" {
            _ = layout.split("a", axis: .horizontal, into: pane)
        }
        return PaneSplitAnchor.Tab(root: root, layout: layout, contents: contents)
    }

    @Test func theChatBesideIsTheOneInTheCanvasSplit() {
        let canvas = PaneContent.tool("canvas")
        let tabs = [
            tab(root: .chat(active), ["a": .chat(active)]),
            tab(root: .chat(beside), ["a": .chat(beside), "b": canvas]),
        ]
        #expect(CanvasCommentRouting.chatBeside(canvas, in: tabs) == beside)
    }

    @Test func aCanvasAloneInItsTabHasNoChatBeside() {
        let canvas = PaneContent.tool("canvas")
        let tabs = [tab(root: .chat(active), ["a": .chat(active)]), tab(root: canvas, ["a": canvas])]
        #expect(CanvasCommentRouting.chatBeside(canvas, in: tabs) == nil)
    }
}
