import Foundation
import Testing
@testable import Core

@Suite("Removing an orchestrator's worktree", .tags(.git), .scratchDirectory)
struct OrchestratorWorktreeRemovalTests {
    private func row(_ path: String, orchestrator: Bool) -> Workspace {
        Workspace(
            id: .new(), repoID: RepoID("project"), name: "lead", branch: "b/lead",
            path: path, baseBranch: "main", isOrchestrator: orchestrator
        )
    }

    @Test("the orchestrator's own path draws the objection that names it")
    func objectsToOrchestrator() throws {
        let objection = try #require(OrchestratorRole.removalObjection(
            toWorktreeAt: "/tmp/lead", among: [row("/tmp/lead", orchestrator: true)]
        ))

        #expect(objection.contains("lead"))
        #expect(objection.contains("worktree is never removed"))
    }

    @Test("another workspace's path draws no objection")
    func allowsOthers() {
        #expect(OrchestratorRole.removalObjection(
            toWorktreeAt: "/tmp/work",
            among: [row("/tmp/lead", orchestrator: true), row("/tmp/work", orchestrator: false)]
        ) == nil)
        #expect(OrchestratorRole.removalObjection(
            toWorktreeAt: "/tmp/lead-2", among: [row("/tmp/lead", orchestrator: true)]
        ) == nil)
    }

    @Test("the path of a workspace that is not the orchestrator draws no objection")
    func ordinaryAtSamePath() {
        #expect(OrchestratorRole.removalObjection(
            toWorktreeAt: "/tmp/lead", among: [row("/tmp/lead", orchestrator: false)]
        ) == nil)
    }

    @Test("an orchestrator listed after another row at the same path still draws the objection")
    func orchestratorBehindAnotherRow() {
        #expect(OrchestratorRole.removalObjection(
            toWorktreeAt: "/tmp/lead",
            among: [row("/tmp/lead", orchestrator: false), row("/tmp/lead", orchestrator: true)]
        ) != nil)
    }

    @Test("the same folder written differently draws the objection")
    func comparesTheFolder() {
        #expect(OrchestratorRole.removalObjection(
            toWorktreeAt: "/tmp/other/../lead/", among: [row("/tmp/lead", orchestrator: true)]
        ) != nil)
    }

    @Test("a symbolic link to the folder draws the objection")
    func followsLinks() throws {
        let real = TestScratch.unique("orchestrator-real")
        let link = TestScratch.unique("orchestrator-link")
        try FileManager.default.createDirectory(atPath: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: real)

        #expect(OrchestratorRole.removalObjection(
            toWorktreeAt: link, among: [row(real, orchestrator: true)]
        ) != nil)
    }

    @Test("removing the orchestrator's worktree is refused and the folder stays", .tags(.destructive))
    func managerRefuses() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-removal")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Lead the work")
        try await store.setOrchestrator(true, workspaceID: workspace.id)

        let error = await #expect(throws: WorkspaceError.self) {
            try await manager.removeWorktree(of: registered, at: workspace.path, force: true)
        }
        guard case .orchestratorRefused = error else {
            Issue.record("removal failed for another reason: \(String(describing: error))")
            return
        }

        #expect(FileManager.default.fileExists(atPath: workspace.path))
    }

    @Test("a removal without force keeps a worktree with changes", .tags(.destructive))
    func withoutForceKeepsChanges() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-removal")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Some work")
        try TempRepo(existing: workspace.path).write("unfinished.txt", "not committed\n")

        await #expect(throws: (any Error).self) {
            try await manager.removeWorktree(of: registered, at: workspace.path, force: false)
        }

        #expect(TempRepo(existing: workspace.path).exists("unfinished.txt"))
    }

    @Test("archiving a workspace at the path an active orchestrator holds is refused", .tags(.destructive))
    func archiveGoesThroughTheGuard() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".conductor/settings.toml", """
        [scripts]
        archive = 'echo archived > "$UD_ROOT_PATH/archive-marker.txt"'
        """)
        let store = try makeTestStore("orchestrator-removal")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Some work")
        var lead = row(workspace.path, orchestrator: true)
        lead.repoID = registered.id
        _ = try await store.upsert(lead)

        let error = await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered, force: true)
        }
        guard case .orchestratorRefused = error else {
            Issue.record("archive failed for another reason: \(String(describing: error))")
            return
        }

        #expect(FileManager.default.fileExists(atPath: workspace.path))
        #expect(!repo.exists("archive-marker.txt"))
        #expect(try await store.workspace(id: workspace.id)?.state == .active)
    }

    @Test("an archived orchestrator at the same path does not hold the folder", .tags(.destructive))
    func archivedOrchestratorDoesNotBlock() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-removal")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Some work")
        var lead = row(workspace.path, orchestrator: true)
        lead.repoID = registered.id
        lead.archive()
        _ = try await store.upsert(lead)

        try await manager.removeWorktree(of: registered, at: workspace.path, force: true)

        #expect(!FileManager.default.fileExists(atPath: workspace.path))
    }

    @Test("a worktree made by the failed step is discarded")
    func discardsFresh() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-removal")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Some work")
        try TempRepo(existing: workspace.path).write("unfinished.txt", "not committed\n")

        await manager.discardFreshWorktree(of: registered, at: workspace.path)

        #expect(!FileManager.default.fileExists(atPath: workspace.path))
    }

    @Test("removing an ordinary workspace's worktree still removes it", .tags(.destructive))
    func managerRemovesOrdinary() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-removal")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Some work")

        try await manager.removeWorktree(of: registered, at: workspace.path, force: true)

        #expect(!FileManager.default.fileExists(atPath: workspace.path))
    }
}
