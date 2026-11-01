import Foundation
import Testing
@testable import Core

@Suite("Orchestrator announcement")
struct OrchestratorAnnouncementTests {
    private let project = RepoID("project")

    private func workspace(
        _ id: String,
        in repo: RepoID? = nil,
        orchestrator: Bool = false,
        origin: WorkspaceOrigin = .user
    ) -> Workspace {
        Workspace(
            id: WorkspaceID(id), repoID: repo ?? project, name: id, branch: "b/\(id)",
            path: "/tmp/\(id)", baseBranch: "main", origin: origin, isOrchestrator: orchestrator
        )
    }

    @Test("a workspace the owner starts is announced to the project's orchestrator")
    func ownerWorkspaceIsAnnounced() {
        let lead = workspace("lead", orchestrator: true)
        let started = workspace("new")

        #expect(OrchestratorRole.announcedOrchestrator(for: started, among: [lead, started])?.id == lead.id)
    }

    @Test("a workspace another agent starts is announced")
    func agentWorkspaceIsAnnounced() {
        let lead = workspace("lead", orchestrator: true)
        let fixer = workspace("fixer")
        let started = workspace("new", origin: .agent(parentWorkspaceID: fixer.id, spawnToolUseID: "t"))

        #expect(OrchestratorRole.announcedOrchestrator(for: started, among: [lead, fixer, started])?.id == lead.id)
    }

    @Test("a workspace the owner's outside agent starts is announced")
    func ownerClientWorkspaceIsAnnounced() {
        let lead = workspace("lead", orchestrator: true)
        let started = workspace("new", origin: .ownerClient(spawnToolUseID: "t"))

        #expect(OrchestratorRole.announcedOrchestrator(for: started, among: [lead, started])?.id == lead.id)
    }

    @Test("a workspace the orchestrator starts itself is not announced again")
    func orchestratorsOwnStartIsNot() {
        let lead = workspace("lead", orchestrator: true)
        let started = workspace("new", origin: .agent(parentWorkspaceID: lead.id, spawnToolUseID: "t"))

        #expect(OrchestratorRole.announcedOrchestrator(for: started, among: [lead, started]) == nil)
    }

    @Test("the orchestrator is not told about itself")
    func orchestratorIsNotToldOfItself() {
        let lead = workspace("lead", orchestrator: true)

        #expect(OrchestratorRole.announcedOrchestrator(for: lead, among: [lead]) == nil)
    }

    @Test("another project's orchestrator is not told")
    func otherProjectIsNot() {
        let elsewhere = workspace("lead", in: RepoID("other"), orchestrator: true)
        let started = workspace("new")

        #expect(OrchestratorRole.announcedOrchestrator(for: started, among: [elsewhere, started]) == nil)
    }

    @Test("a project with no orchestrator announces nothing")
    func noOrchestratorNoAnnouncement() {
        let started = workspace("new")

        #expect(OrchestratorRole.announcedOrchestrator(for: started, among: [workspace("a"), started]) == nil)
    }
    @Test("an archived orchestrator is not told")
    func archivedOrchestratorIsNot() {
        var lead = workspace("lead", orchestrator: true)
        lead.archive()
        let started = workspace("new")

        #expect(OrchestratorRole.announcedOrchestrator(for: started, among: [lead, started]) == nil)
    }
}
