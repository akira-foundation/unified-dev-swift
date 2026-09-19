import Testing
@testable import Core

@Suite("Where a tab the bridge opens lands")
struct PanePlacementTests {
    @Test("a tab opened in the background stays behind the tab in front")
    func backgroundStaysBehind() {
        #expect(PaneOrder(kind: .terminal, focus: false).placement(hasTabInFront: true) == .behind)
        #expect(PaneOrder(kind: .chat, focus: false).placement(hasTabInFront: true) == .behind)
        #expect(
            TerminalStartOrder(command: "bun run dev", focus: false).placement(hasTabInFront: true)
                == .behind
        )
    }

    @Test("with nothing in front, a tab opened in the background is the one shown")
    func backgroundWithNothingInFront() {
        #expect(PaneOrder(kind: .terminal, focus: false).placement(hasTabInFront: false) == .front)
        #expect(
            TerminalStartOrder(command: "ls", focus: false).placement(hasTabInFront: false) == .front
        )
    }

    @Test("focus brings the tab to the front whatever is there")
    func focusBringsItForward() {
        #expect(PaneOrder(kind: .chat).placement(hasTabInFront: true) == .front)
        #expect(TerminalStartOrder(command: "ls").placement(hasTabInFront: true) == .front)
        #expect(TerminalStartOrder(command: "ls").placement(hasTabInFront: false) == .front)
    }

    @Test("the confirmation says where the tab went, not what was asked")
    func confirmationFollowsThePlacement() {
        let background = PaneOrder(kind: .terminal, focus: false)
        #expect(background.confirmation(for: .behind).contains("background"))
        #expect(background.confirmation(for: .front).contains("front"))
        #expect(!background.confirmation(for: .front).contains("background"))
    }

    @Test("a terminal's confirmation says where it went, not what was asked")
    func terminalConfirmationFollowsThePlacement() {
        let background = TerminalStartOrder(command: "ls", focus: false)
        let behind = background.confirmation(title: "Build", for: .behind)
        let front = background.confirmation(title: "Build", for: .front)
        #expect(behind.contains("'Build' in the background"))
        #expect(front.contains("'Build' and brought it to the front"))
        #expect(!front.contains("background"))
        #expect(front.contains("terminal_read"))
    }
}
