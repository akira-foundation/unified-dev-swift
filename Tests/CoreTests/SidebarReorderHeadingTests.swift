import Foundation
import Testing
@testable import Core

@Suite("Sidebar reorder with status headings")
struct SidebarReorderHeadingTests {
    private var rows: [SidebarReorder.Row] {
        [
            .heading,
            .workspace(id: WorkspaceID("a1"), projectID: RepoID("alpha")),
            .heading,
            .workspace(id: WorkspaceID("b1"), projectID: RepoID("beta")),
        ]
    }

    @Test("a status heading is never something to move")
    func headingIsNotDragged() {
        #expect(SidebarReorder.destination(rows: rows, from: [0], to: 4) == .nothing)
        #expect(SidebarReorder.destination(rows: rows, from: [2], to: 0) == .nothing)
    }

    @Test("a heading does not extend a project's run of rows")
    func headingDoesNotTrail() {
        let destination = SidebarReorder.destination(rows: rows, from: [1], to: 3)

        #expect(destination == .workspace(
            projectID: RepoID("alpha"), from: IndexSet(integer: 0), to: 1, landedOutside: true
        ))
    }
}
