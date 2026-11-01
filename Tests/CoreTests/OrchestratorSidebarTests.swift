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
