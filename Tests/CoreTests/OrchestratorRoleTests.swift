import Foundation
import Testing
@testable import Core

@Suite("Orchestrator role")
struct OrchestratorRoleTests {
    private let project = RepoID("project")

    private func workspace(
        _ id: String,
        in repo: RepoID? = nil,
        orchestrator: Bool = false,
        archived: Bool = false
    ) -> Workspace {
        var row = Workspace(
            id: WorkspaceID(id), repoID: repo ?? project, name: id, branch: "b/\(id)",
            path: "/tmp/\(id)", baseBranch: "main", isOrchestrator: orchestrator
        )
        if archived { row.archive() }
        return row
    }

    @Test("the first workspace of a project is asked about")
    func firstIsAsked() {
        #expect(OrchestratorRole.asksAtCreation(repoID: project, workspaces: []))
        #expect(OrchestratorRole.asksAtCreation(
            repoID: project, workspaces: [workspace("elsewhere", in: RepoID("other"))]
        ))
        #expect(OrchestratorRole.asksAtCreation(
            repoID: project, workspaces: [workspace("gone", archived: true)]
        ))
    }

    @Test("a project that already has a workspace is not asked again")
    func laterIsNotAsked() {
        #expect(!OrchestratorRole.asksAtCreation(repoID: project, workspaces: [workspace("a")]))
        #expect(!OrchestratorRole.asksAtCreation(
            repoID: project, workspaces: [workspace("o", orchestrator: true)]
        ))
    }

    @Test("a project with no orchestrator may have one")
    func firstAssignmentIsAllowed() {
        let candidate = workspace("a")
        let others = [candidate, workspace("b"), workspace("x", in: RepoID("other"), orchestrator: true)]
        #expect(OrchestratorRole.assignment(of: candidate, among: others) == .allowed)
    }

    @Test("a second orchestrator in the same project is refused, naming the first")
    func secondIsRefused() {
        let candidate = workspace("b")
        let current = workspace("lead", orchestrator: true)
        guard case .refused(let sentence) = OrchestratorRole.assignment(
            of: candidate, among: [current, candidate]
        ) else {
            Issue.record("a second orchestrator was allowed")
            return
        }
        #expect(sentence.contains("lead"))
    }

    @Test("a workspace not made yet is refused the role while the project has an orchestrator")
    func newcomer() {
        let current = workspace("lead", orchestrator: true)
        #expect(OrchestratorRole.assignment(in: project, among: []) == .allowed)
        #expect(OrchestratorRole.assignment(in: project, among: [current]) != .allowed)
        #expect(OrchestratorRole.assignment(in: RepoID("other"), among: [current]) == .allowed)
    }

    @Test("marking the current orchestrator again is not a second one")
    func sameIsAllowed() {
        let current = workspace("lead", orchestrator: true)
        #expect(OrchestratorRole.assignment(of: current, among: [current]) == .allowed)
    }

    @Test("an archived workspace cannot become the orchestrator")
    func archivedIsRefused() {
        let candidate = workspace("old", archived: true)
        #expect(OrchestratorRole.assignment(of: candidate, among: [candidate]) != .allowed)
    }

    @Test("an orchestrator is always pinned, and anything else keeps what it asked for")
    func pinnedFollowsRole() {
        #expect(OrchestratorRole.pinned(false, isOrchestrator: true))
        #expect(OrchestratorRole.pinned(true, isOrchestrator: true))
        #expect(!OrchestratorRole.pinned(false, isOrchestrator: false))
        #expect(OrchestratorRole.pinned(true, isOrchestrator: false))
    }

    @Test("an orchestrator objects to being archived, and nothing else does on its account")
    func archiveObjection() {
        #expect(OrchestratorRole.archiveObjection(to: workspace("lead", orchestrator: true)) != nil)
        #expect(OrchestratorRole.archiveObjection(to: workspace("a")) == nil)
    }

    @Test("a caller that is the orchestrator hears back from every workspace it starts")
    func watchesByDefault() {
        #expect(OrchestratorRole.watchesStartedWorkspaces(requested: false, callerIsOrchestrator: true))
        #expect(!OrchestratorRole.watchesStartedWorkspaces(requested: false, callerIsOrchestrator: false))
        #expect(OrchestratorRole.watchesStartedWorkspaces(requested: true, callerIsOrchestrator: false))
    }
}
