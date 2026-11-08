import Foundation
import Testing
@testable import Core

@Suite("Orchestrator in the sidebar")
struct OrchestratorSidebarTests {
    private func workspace(
        _ id: String, order: Int, pinned: Bool = false, orchestrator: Bool = false, parent: String? = nil
    ) -> Workspace {
        var row = Workspace(
            id: WorkspaceID(id), repoID: RepoID("r1"), name: id, branch: "b/\(id)",
            path: "/tmp/\(id)", baseBranch: "main", sortOrder: order, pinned: pinned,
            isOrchestrator: orchestrator
        )
        if let parent { row.origin = .agent(parentWorkspaceID: WorkspaceID(parent), spawnToolUseID: id) }
        return row
    }

    @Test("the orchestrator is the first row of its project, above every other pinned row")
    func orchestratorLeads() {
        let rows = [
            workspace("pinned", order: 0, pinned: true),
            workspace("plain", order: 1),
            workspace("lead", order: 9, pinned: true, orchestrator: true),
        ]
        #expect(SidebarReorder.drawn(rows).map(\.id.rawValue) == ["lead", "pinned", "plain"])
    }

    @Test("the workspaces the orchestrator started follow it, before the rest")
    func childrenFollow() {
        let rows = [
            workspace("pinned", order: 0, pinned: true),
            workspace("child-b", order: 5, parent: "lead"),
            workspace("plain", order: 1),
            workspace("lead", order: 9, pinned: true, orchestrator: true),
            workspace("child-a", order: 2, parent: "lead"),
            workspace("crew", order: 3, parent: "plain"),
        ]
        #expect(SidebarReorder.drawn(rows).map(\.id.rawValue)
            == ["lead", "child-a", "child-b", "pinned", "plain", "crew"])
    }

    @Test("without an orchestrator the order is what it always was")
    func noOrchestrator() {
        let rows = [
            workspace("a", order: 0),
            workspace("b", order: 1, pinned: true),
            workspace("c", order: 2, parent: "a"),
        ]
        #expect(SidebarReorder.drawn(rows).map(\.id.rawValue) == ["b", "a", "c"])
    }

    @Test("the orchestrator and its children keep their place against a drag")
    func familyIsFixed() {
        let rows = [
            workspace("lead", order: 0, pinned: true, orchestrator: true),
            workspace("child", order: 1, parent: "lead"),
            workspace("plain", order: 2),
        ]
        #expect(SidebarReorder.isFixedInPlace(rows[0], among: rows))
        #expect(SidebarReorder.isFixedInPlace(rows[1], among: rows))
        #expect(!SidebarReorder.isFixedInPlace(rows[2], among: rows))
    }

    @Test("a child row is indented under its orchestrator and nowhere else")
    func childIndent() {
        let rows = [
            workspace("lead", order: 0, pinned: true, orchestrator: true),
            workspace("child", order: 1, parent: "lead"),
            workspace("crew", order: 2, parent: "child"),
        ]
        #expect(SidebarReorder.isOrchestratorChild(rows[1], among: rows))
        #expect(!SidebarReorder.isOrchestratorChild(rows[0], among: rows))
        #expect(!SidebarReorder.isOrchestratorChild(rows[2], among: rows))
    }

    private func foldsColumn(
        of row: Workspace,
        among rows: [Workspace],
        drawn: [Workspace]? = nil,
        status: (Workspace) -> WorkspaceStatus = { _ in .clean }
    ) -> Bool {
        SidebarMarkPolicy.foldsMarkColumn(
            of: row, among: rows, drawn: Set((drawn ?? rows).map(\.id)), status: status
        )
    }

    @Test("the mark column folds while no sibling has a mark to draw")
    func columnFoldsWhenTheFamilyIsSilent() {
        let rows = [
            workspace("lead", order: 0, orchestrator: true),
            workspace("one", order: 1, parent: "lead"),
            workspace("two", order: 2, parent: "lead"),
        ]
        #expect(foldsColumn(of: rows[1], among: rows))
        #expect(foldsColumn(of: rows[2], among: rows) { _ in .changed })
    }

    @Test("one sibling with a mark keeps the column open for the whole family")
    func oneMarkKeepsTheColumn() {
        let rows = [
            workspace("lead", order: 0, orchestrator: true),
            workspace("one", order: 1, parent: "lead"),
            workspace("two", order: 2, parent: "lead"),
        ]
        let status: (Workspace) -> WorkspaceStatus = { $0.id == rows[2].id ? .running : .clean }
        #expect(!foldsColumn(of: rows[1], among: rows, status: status))
        #expect(!foldsColumn(of: rows[2], among: rows, status: status))
    }

    @Test("a mark under another orchestrator or in another project leaves this family's column alone")
    func strangersDoNotKeepTheColumn() {
        let lead = workspace("lead", order: 0, orchestrator: true)
        let quiet = workspace("quiet", order: 1, parent: "lead")
        var elsewhere = workspace("elsewhere", order: 2, parent: "lead")
        elsewhere.repoID = RepoID("r2")
        let other = workspace("other", order: 3, parent: "other-lead")
        let folds = foldsColumn(of: quiet, among: [lead, quiet, elsewhere, other]) {
            $0.id == quiet.id ? .clean : .running
        }
        #expect(folds)
    }

    @Test("a sibling the sidebar does not draw cannot keep the column open")
    func undrawnSiblingDoesNotKeepTheColumn() {
        let lead = workspace("lead", order: 0, orchestrator: true)
        let shown = workspace("shown", order: 1, parent: "lead")
        let filtered = workspace("filtered", order: 2, parent: "lead")
        let folds = foldsColumn(of: shown, among: [lead, shown, filtered], drawn: [shown]) {
            $0.id == filtered.id ? .running : .clean
        }
        #expect(folds)
    }

    @Test("a sibling that is an orchestrator keeps the column, because its role mark is drawn in it")
    func roleMarkKeepsTheColumn() {
        let rows = [
            workspace("lead", order: 0, orchestrator: true),
            workspace("one", order: 1, parent: "lead"),
            workspace("nested", order: 2, orchestrator: true, parent: "lead"),
        ]
        #expect(!foldsColumn(of: rows[1], among: rows))
    }

    @Test("a row that is no orchestrator's child never folds its column")
    func onlyAChildFolds() {
        let plain = workspace("plain", order: 0)
        let parent = workspace("parent", order: 1)
        let crew = workspace("crew", order: 2, parent: "parent")
        #expect(!foldsColumn(of: plain, among: [plain]))
        #expect(!foldsColumn(of: crew, among: [parent, crew]))
    }

    @Test("a child started into another project is not drawn as a child there")
    func childInAnotherProject() {
        let lead = workspace("lead", order: 0, pinned: true, orchestrator: true)
        var stranger = workspace("stranger", order: 1, parent: "lead")
        stranger.repoID = RepoID("r2")
        #expect(!SidebarReorder.isOrchestratorChild(stranger, among: [lead, stranger]))
        #expect(!SidebarReorder.isFixedInPlace(stranger, among: [lead, stranger]))
    }

    @Test("a pinned row dropped between the orchestrator and its child stays pinned")
    func dropInsideTheFamily() throws {
        let rows = [
            workspace("lead", order: 0, pinned: true, orchestrator: true),
            workspace("child", order: 1, parent: "lead"),
            workspace("first", order: 2, pinned: true),
            workspace("second", order: 3, pinned: true),
            workspace("plain", order: 4),
        ]
        let visible = SidebarReorder.drawn(rows)
        #expect(visible.map(\.id.rawValue) == ["lead", "child", "first", "second", "plain"])

        let changes = SidebarReorder.move(visible: visible, all: rows, from: IndexSet(integer: 3), to: 1)

        let moved = try #require(changes.first { $0.id.rawValue == "second" })
        #expect(moved.pinned)
    }

    @Test("the orchestrator wears its own symbol in place of a quiet status",
          arguments: [WorkspaceStatus.clean, .changed, .unread, .merged, .pullRequestOpen, .checksFailing])
    func symbolReplacesStatus(_ status: WorkspaceStatus) {
        #expect(SidebarRoleMark.symbol(isOrchestrator: true, status: status) == SidebarRoleMark.orchestrator)
    }

    @Test("work in progress still shows over the orchestrator's symbol",
          arguments: [WorkspaceStatus.running, .awaitingPermission, .settingUp, .setupFailed])
    func activityWins(_ status: WorkspaceStatus) {
        #expect(SidebarRoleMark.symbol(isOrchestrator: true, status: status) == nil)
    }

    @Test("an ordinary workspace has no role symbol")
    func ordinary() {
        for status in WorkspaceStatus.allCases {
            #expect(SidebarRoleMark.symbol(isOrchestrator: false, status: status) == nil)
        }
        #expect(SidebarRoleMark.orchestrator == "point.3.connected.trianglepath.dotted")
    }
}
