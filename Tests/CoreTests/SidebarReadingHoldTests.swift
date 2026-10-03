import Testing
@testable import Core

@Suite("Sidebar reading hold")
struct SidebarReadingHoldTests {
    private func workspace(_ id: String, unread: Bool) -> Workspace {
        Workspace(
            id: WorkspaceID(id),
            repoID: RepoID("r1"),
            name: id,
            branch: "unifieddev/\(id)",
            path: "/tmp/\(id)",
            baseBranch: "main",
            unread: unread
        )
    }

    @Test("selecting an unread workspace holds it")
    func holdsUnread() {
        let hold = SidebarReadingHold.next(
            selection: .workspace(WorkspaceID("a")), current: nil, workspaces: [workspace("a", unread: true)]
        )

        #expect(hold == WorkspaceID("a"))
    }

    @Test("selecting a read workspace holds nothing")
    func ignoresRead() {
        let hold = SidebarReadingHold.next(
            selection: .workspace(WorkspaceID("a")), current: nil, workspaces: [workspace("a", unread: false)]
        )

        #expect(hold == nil)
    }

    @Test("the hold survives the flag clearing while the workspace stays selected")
    func survivesFlagClearing() {
        let id = WorkspaceID("a")
        let hold = SidebarReadingHold.next(
            selection: .workspace(id), current: id, workspaces: [workspace("a", unread: false)]
        )

        #expect(hold == id)
    }

    @Test("leaving the workspace releases it")
    func leavingReleases() {
        let rows = [workspace("a", unread: false), workspace("b", unread: false)]
        let id = WorkspaceID("a")

        #expect(SidebarReadingHold.next(selection: .workspace(WorkspaceID("b")), current: id, workspaces: rows) == nil)
        #expect(SidebarReadingHold.next(selection: .home, current: id, workspaces: rows) == nil)
        #expect(SidebarReadingHold.next(selection: .draft(RepoID("r1")), current: id, workspaces: rows) == nil)
    }

    @Test("opening a subagent, a crew member or a call of the held workspace keeps it held")
    func staysWithinTheWorkspace() {
        let id = WorkspaceID("a")
        let rows = [workspace("a", unread: false)]

        #expect(SidebarReadingHold.next(selection: .subagent(id, SubagentID("s")), current: id, workspaces: rows) == id)
        #expect(SidebarReadingHold.next(selection: .crew(id, SessionID("c")), current: id, workspaces: rows) == id)
        #expect(SidebarReadingHold.next(selection: .subagentCall(id, toolUseID: "t"), current: id, workspaces: rows) == id)
    }

    @Test("only selecting the workspace itself starts a hold")
    func onlyTheWorkspaceStartsOne() {
        let hold = SidebarReadingHold.next(
            selection: .subagent(WorkspaceID("a"), SubagentID("s")),
            current: nil,
            workspaces: [workspace("a", unread: true)]
        )

        #expect(hold == nil)
    }

    @Test("an archived workspace is not held")
    func archivedIsNotHeld() {
        var archived = workspace("a", unread: true)
        archived.state = .archived

        let hold = SidebarReadingHold.next(selection: .workspace(archived.id), current: nil, workspaces: [archived])

        #expect(hold == nil)
    }

    @Test("a held workspace is listed in Ready to read")
    func heldIsListed() {
        let rows = [workspace("a", unread: false), workspace("b", unread: false)]
        let listing = SidebarStatusListing.build(workspaces: rows, holding: WorkspaceID("a"), status: { _ in .clean })

        #expect(listing.sections.map(\.group) == [.readyToRead, .idle])
    }
}
