import Testing
@testable import Core

@Suite("Sidebar selection")
struct SidebarSelectionTests {
    private let workspace = WorkspaceID("w1")
    private let subagent = SubagentID("s1")
    private let crewMember = SessionID("c1")

    @Test("a subagent carries its workspace")
    func aSubagentIsAWorkspaceSelection() {
        #expect(SidebarSelection.subagent(workspace, subagent).workspaceID == workspace)
        #expect(SidebarSelection.subagent(workspace, subagent).subagentID == subagent)
        #expect(SidebarSelection.workspace(workspace).subagentID == nil)
    }

    @Test("a run opened from its call carries its workspace and no roster id")
    func aSubagentCallIsAWorkspaceSelection() {
        let call = SidebarSelection.subagentCall(workspace, toolUseID: "toolu_1")
        #expect(call.workspaceID == workspace)
        #expect(call.subagentID == nil)
        #expect(call != .subagentCall(workspace, toolUseID: "toolu_2"))
    }

    @Test("an archived workspace is not reachable as a live one")
    func archivedIsNotLive() {
        #expect(SidebarSelection.archived(workspace).workspaceID == nil)
        #expect(SidebarSelection.archived(workspace).archivedWorkspaceID == workspace)
        #expect(SidebarSelection.workspace(workspace).archivedWorkspaceID == nil)
    }

    @Test("Home carries no workspace at all")
    func homeCarriesNothing() {
        #expect(SidebarSelection.home.workspaceID == nil)
        #expect(SidebarSelection.home.archivedWorkspaceID == nil)
        #expect(SidebarSelection.home.subagentID == nil)
        #expect(SidebarSelection.home.crewSessionID == nil)
    }

    @Test("Ask Unified Dev carries no workspace either, and is not Home")
    func askCarriesNothing() {
        #expect(SidebarSelection.ask.workspaceID == nil)
        #expect(SidebarSelection.ask.archivedWorkspaceID == nil)
        #expect(SidebarSelection.ask.subagentID == nil)
        #expect(SidebarSelection.ask != .home)
        #expect(Set<SidebarSelection>([.ask, .home]).count == 2)
    }

    @Test("the same id archived and live are different selections")
    func archivedAndLiveDoNotCollide() {
        #expect(SidebarSelection.workspace(workspace) != .archived(workspace))
        #expect(
            SidebarSelection.workspace(workspace).hashValue
                != SidebarSelection.archived(workspace).hashValue
        )
        #expect(Set<SidebarSelection>([.workspace(workspace), .archived(workspace)]).count == 2)
    }

    @Test("a crew member carries its workspace")
    func aCrewMemberIsAWorkspaceSelection() {
        #expect(SidebarSelection.crew(workspace, crewMember).workspaceID == workspace)
        #expect(SidebarSelection.crew(workspace, crewMember).crewSessionID == crewMember)
        #expect(SidebarSelection.workspace(workspace).crewSessionID == nil)
        #expect(SidebarSelection.crew(workspace, crewMember).subagentID == nil)
        #expect(SidebarSelection.subagent(workspace, subagent).crewSessionID == nil)
    }

    @Test("two crew members of one workspace are different selections")
    func crewDoNotCollide() {
        let other = SessionID("c2")
        #expect(SidebarSelection.crew(workspace, crewMember) != .crew(workspace, other))
        #expect(SidebarSelection.crew(workspace, crewMember) != .workspace(workspace))
        #expect(Set<SidebarSelection>([
            .crew(workspace, crewMember), .crew(workspace, other), .workspace(workspace)
        ]).count == 3)
    }

    @Test("two subagents of one workspace are different selections")
    func subagentsDoNotCollide() {
        let other = SubagentID("s2")
        #expect(SidebarSelection.subagent(workspace, subagent) != .subagent(workspace, other))
        #expect(SidebarSelection.subagent(workspace, subagent) != .workspace(workspace))
    }

    @Test("every selection answers for the workspace it is about, or says it is about none")
    func everySelectionIsClassified() {
        let carrying: [SidebarSelection] = [
            .workspace(workspace), .subagent(workspace, subagent), .crew(workspace, crewMember),
        ]
        #expect(carrying.allSatisfy { $0.workspaceID == workspace })

        let carryingNone: [SidebarSelection] = [.home, .ask, .archived(workspace)]
        #expect(carryingNone.allSatisfy { $0.workspaceID == nil })
        #expect(SidebarSelection.archived(workspace).archivedWorkspaceID == workspace)
    }
}
