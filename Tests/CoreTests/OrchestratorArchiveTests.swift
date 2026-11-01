import Foundation
import Testing
@testable import Core

@Suite("Orchestrator archive", .tags(.git), .scratchDirectory)
struct OrchestratorArchiveTests {
    @Test("archiving the orchestrator is refused and its worktree stays", .tags(.destructive))
    func archiveIsRefused() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-archive")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Lead the work")
        try await store.setOrchestrator(true, workspaceID: workspace.id)

        let error = await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered, force: true, isPullRequestMerged: true)
        }
        guard case .orchestratorRefused = error else {
            Issue.record("archive failed for another reason: \(String(describing: error))")
            return
        }

        #expect(FileManager.default.fileExists(atPath: workspace.path))
        #expect(try await store.workspace(id: workspace.id)?.state == .active)
    }

    @Test("a workspace started as the orchestrator is one before its first chat opens", .tags(.destructive))
    func startMarksBeforeTheChat() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-archive")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Lead the work", origin: .user, opensSession: true, orchestrates: true
        ))

        let stored = try #require(try await store.workspace(id: started.workspace.id))
        #expect(stored.isOrchestrator)
        #expect(stored.pinned)
        #expect(started.workspace.isOrchestrator)
        #expect(started.session != nil)
    }

    @Test("a second workspace asked to be the orchestrator is refused before any worktree is cut", .tags(.destructive))
    func secondStartIsRefusedEarly() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-archive")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        _ = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Lead", origin: .user, opensSession: false, orchestrates: true
        ))

        await #expect(throws: WorkspaceError.self) {
            try await manager.start(WorkspaceStartRequest(
                repo: registered, prompt: "Also lead", origin: .user, opensSession: false, orchestrates: true
            ))
        }
        #expect(try await store.workspaces(repoID: registered.id).count == 1)
    }

    @Test("an archived orchestrator still holds the role, and a new one is refused before any worktree", .tags(.destructive))
    func archivedOrchestratorHoldsTheRole() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-archive")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let lead = try await manager.createWorkspace(repo: registered, prompt: "Lead")
        try await store.setOrchestrator(true, workspaceID: lead.id)
        try await store.update(workspaceID: lead.id) { $0.archive() }
        let worktrees = try FileManager.default.contentsOfDirectory(atPath: (lead.path as NSString).deletingLastPathComponent)

        let error = await #expect(throws: WorkspaceError.self) {
            try await manager.start(WorkspaceStartRequest(
                repo: registered, prompt: "Also lead", origin: .user, opensSession: false, orchestrates: true
            ))
        }

        guard case .orchestratorRefused = error else {
            Issue.record("the start failed for another reason: \(String(describing: error))")
            return
        }
        #expect(try await store.workspaces(repoID: registered.id, includeArchived: true).count == 1)
        let after = try FileManager.default.contentsOfDirectory(atPath: (lead.path as NSString).deletingLastPathComponent)
        #expect(after.sorted() == worktrees.sorted())
    }
}
