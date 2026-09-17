import Testing
@testable import Core

@Suite("Archive navigation")
struct ArchiveNavigationTests {
    private let archived = WorkspaceID("w1")
    private let other = WorkspaceID("w2")

    @Test("the window on the archived workspace goes to Home")
    func theOpenWorkspaceLeaves() {
        #expect(
            ArchiveNavigation.destination(
                leaving: .workspace(archived), archiving: archived
            ) == .home
        )
    }

    @Test("a child of the archived workspace leaves with it")
    func childrenLeaveToo() {
        let subagent = SidebarSelection.subagent(archived, SubagentID("s1"))
        let crew = SidebarSelection.crew(archived, SessionID("c1"))
        #expect(ArchiveNavigation.destination(leaving: subagent, archiving: archived) == .home)
        #expect(ArchiveNavigation.destination(leaving: crew, archiving: archived) == .home)
    }

    @Test("a window that moved to another workspace stays there")
    func anotherWorkspaceIsLeftAlone() {
        #expect(ArchiveNavigation.destination(leaving: .workspace(other), archiving: archived) == nil)
        #expect(
            ArchiveNavigation.destination(
                leaving: .subagent(other, SubagentID("s1")), archiving: archived
            ) == nil
        )
        #expect(
            ArchiveNavigation.destination(
                leaving: .crew(other, SessionID("c1")), archiving: archived
            ) == nil
        )
    }

    @Test("a window on no workspace is not moved")
    func destinationsWithNoWorkspaceAreLeftAlone() {
        #expect(ArchiveNavigation.destination(leaving: .home, archiving: archived) == nil)
        #expect(ArchiveNavigation.destination(leaving: .ask, archiving: archived) == nil)
    }

    @Test("the archived reader is not what this moves")
    func theArchivedReaderStays() {
        #expect(ArchiveNavigation.destination(leaving: .archived(archived), archiving: archived) == nil)
    }

    @Test("asking again after the window has left answers nothing")
    func askingTwiceMovesOnce() {
        var selection = SidebarSelection.workspace(archived)
        if let first = ArchiveNavigation.destination(leaving: selection, archiving: archived) {
            selection = first
        }
        #expect(selection == .home)
        #expect(ArchiveNavigation.destination(leaving: selection, archiving: archived) == nil)
    }
}
