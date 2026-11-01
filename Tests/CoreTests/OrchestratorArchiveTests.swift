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

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered, force: true, isPullRequestMerged: true)
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
            repo: registered, prompt: "Lead the work", origin: .user, opensSession: false, orchestrates: true
        ))

        let stored = try #require(try await store.workspace(id: started.workspace.id))
        #expect(stored.isOrchestrator)
        #expect(stored.pinned)
        #expect(started.workspace.isOrchestrator)
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
}
