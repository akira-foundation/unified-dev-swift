import Testing
@testable import Core

@Suite("What Cmd+W closes")
struct TabClosureTests {
    private let chat = PaneContent.chat(SessionID("session-1"))
    private let terminal = PaneContent.tool("tool-1")

    @Test("a tab nobody has split closes itself")
    func unsplitTab() {
        #expect(TabClosure.target(selectedTab: terminal, focusedPaneContent: terminal) == terminal)
    }

    @Test("the tab in front is what closes, not the workspace's conversation")
    func theTabInFront() {
        #expect(TabClosure.target(selectedTab: terminal, focusedPaneContent: nil) == terminal)
        #expect(TabClosure.target(selectedTab: terminal, focusedPaneContent: terminal) != chat)
    }

    @Test("a split tab closes the pane the keyboard is in")
    func splitTab() {
        #expect(TabClosure.target(selectedTab: chat, focusedPaneContent: terminal) == terminal)
        #expect(TabClosure.target(selectedTab: chat, focusedPaneContent: chat) == chat)
    }

    @Test("a workspace with no tabs has nothing to close")
    func nothingOpen() {
        #expect(TabClosure.target(selectedTab: nil, focusedPaneContent: nil) == nil)
        #expect(TabClosure.target(selectedTab: nil, focusedPaneContent: chat) == nil)
    }
}
