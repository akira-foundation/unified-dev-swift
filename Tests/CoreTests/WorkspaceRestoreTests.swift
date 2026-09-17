import Testing
import Foundation
@testable import Core

@Suite("Restoring an archived workspace", .tags(.git, .destructive), .scratchDirectory)
struct WorkspaceRestoreTests {
    private func makeWorkspace(
        settings: String? = nil,
        prompt: String = "Restore a workspace"
    ) async throws -> (repo: TempRepo, registered: Repo, manager: WorkspaceManager, workspace: Workspace) {
        let repo = try await TempRepo()
        if let settings { try repo.write(".conductor/settings.toml", settings) }
        let manager = WorkspaceManager(store: try makeTestStore("restore"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: prompt)
        return (repo, registered, manager, workspace)
    }

    private func commit(in worktree: String, message: String) async throws {
        try await Shell.check("git", ["add", "-A"], cwd: worktree)
        try await Shell.check("git", [
            "-c", "user.email=test@unifieddev.local", "-c", "user.name=Unified Dev Test",
            "-c", "commit.gpgsign=false", "commit", "-q", "-m", message,
        ], cwd: worktree)
    }

    @Test("an archived worktree comes back at the same path, on the same branch, at the same commit")
    func roundTrip() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try TempRepo(existing: workspace.path).write("feature.txt", "committed work\n")
        try await commit(in: workspace.path, message: "committed work")
        let sha = try await Git.headSHA(of: workspace.path)

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.isSafeToDiscard == false)
        #expect(report.isRestorableFromBranch)

        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: false, force: true
        )
        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)

        let outcome = try await manager.restore(workspace: workspace, repo: registered)

        #expect(FileManager.default.fileExists(atPath: workspace.path))
        #expect(try await Git.currentBranch(of: workspace.path) == workspace.branch)
        #expect(try await Git.headSHA(of: workspace.path) == sha)
        #expect(TempRepo(existing: workspace.path).read("feature.txt") == "committed work\n")
        #expect(outcome.source == .localBranch)
        #expect(outcome.relocatedFrom == nil)
        #expect(outcome.workspace.state == .active)
        #expect(outcome.workspace.archivedAt == nil)
        #expect(outcome.workspace.path == workspace.path)
    }

    @Test("the stored workspace is active again, so the sidebar lists it")
    func theStoreAgreesTheWorkspaceIsBack() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        #expect(try await manager.store.workspaces().contains { $0.id == workspace.id } == false)

        try await manager.restore(workspace: workspace, repo: registered)
        #expect(try await manager.store.workspaces().contains { $0.id == workspace.id })
    }

    @Test("the copied files come back, because git never had them")
    func copiedFilesAreRestored() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".gitignore", ".env\n")
        try repo.write(".env", "TOKEN=from-the-checkout\n")
        try await repo.commit("ignore the env")

        let manager = WorkspaceManager(store: try makeTestStore("restore-copies"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Copy the env")
        #expect(TempRepo(existing: workspace.path).read(".env") == "TOKEN=from-the-checkout\n")

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        try await manager.restore(workspace: workspace, repo: registered)

        #expect(TempRepo(existing: workspace.path).read(".env") == "TOKEN=from-the-checkout\n")
    }

    @Test("a branch deleted here but still on the remote is cut again from the remote")
    func restoresFromTheRemote() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try TempRepo(existing: workspace.path).write("feature.txt", "work that was pushed\n")
        try await commit(in: workspace.path, message: "work that was pushed")
        let sha = try await Git.headSHA(of: workspace.path)

        let origin = TestScratch.unique("origin") + ".git"
        try await Shell.check("git", ["init", "--bare", "-q", origin])
        try await Shell.check("git", ["remote", "add", "origin", origin], cwd: repo.path)
        try await Shell.check("git", ["push", "-q", "origin", workspace.branch], cwd: workspace.path)

        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: true, force: true
        )
        #expect(await Git.branchExists(workspace.branch, in: registered.path) == false)

        let source = await manager.restoreSource(workspace: workspace, repo: registered)
        #expect(source == .remoteBranch(ref: "refs/remotes/origin/\(workspace.branch)"))
        #expect(source.canRebuild)

        let outcome = try await manager.restore(workspace: workspace, repo: registered)

        #expect(outcome.source == source)
        #expect(FileManager.default.fileExists(atPath: outcome.workspace.path))
        #expect(try await Git.currentBranch(of: outcome.workspace.path) == workspace.branch)
        #expect(try await Git.headSHA(of: outcome.workspace.path) == sha)
        #expect(TempRepo(existing: outcome.workspace.path).read("feature.txt")
            == "work that was pushed\n")
        #expect(await Git.branchExists(workspace.branch, in: registered.path))
    }

    @Test("a worktree whose path is taken is rebuilt beside it, and the squatter is untouched")
    func relocatesWhenSomethingIsAtThePath() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        try FileManager.default.createDirectory(
            atPath: workspace.path, withIntermediateDirectories: true
        )
        try TempRepo(existing: workspace.path).write("someone-elses.txt", "not ours\n")

        let outcome = try await manager.restore(workspace: workspace, repo: registered)

        #expect(outcome.relocatedFrom == workspace.path)
        #expect(outcome.workspace.path == workspace.path + "-2")
        #expect(try await Git.currentBranch(of: outcome.workspace.path) == workspace.branch)
        #expect(TempRepo(existing: workspace.path).read("someone-elses.txt") == "not ours\n")
    }

    @Test("a workspace whose branch is gone everywhere cannot be restored")
    func refusesWhenTheBranchIsGone() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true)
        #expect(await manager.canRestore(workspace: workspace, repo: registered) == false)
        #expect(await manager.restoreSource(workspace: workspace, repo: registered) == .gone)

        await #expect(throws: WorkspaceRestoreRefusal.self) {
            try await manager.restore(workspace: workspace, repo: registered)
        }
        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
    }

    @Test("a live workspace is not restorable, because nothing was removed")
    func aLiveWorkspaceIsNotRestorable() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        #expect(await manager.canRestore(workspace: workspace, repo: registered) == false)
    }

    @Test("an archive that kept the branch is restorable")
    func archiveKeepingTheBranchIsRestorable() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        #expect(await manager.canRestore(workspace: workspace, repo: registered))
        #expect(await manager.restoreSource(workspace: workspace, repo: registered) == .localBranch)
    }

    @Test("a surviving local branch wins over anything the remote has")
    func theLocalBranchWins() {
        #expect(RestoreSource.of(hasLocalBranch: true, remoteRef: nil) == .localBranch)
        #expect(RestoreSource.of(hasLocalBranch: true, remoteRef: "refs/remotes/origin/x")
            == .localBranch)
    }

    @Test("with no local branch the remote is the next best thing")
    func theRemoteIsNext() {
        #expect(RestoreSource.of(hasLocalBranch: false, remoteRef: "refs/remotes/origin/x")
            == .remoteBranch(ref: "refs/remotes/origin/x"))
    }

    @Test("with neither, the branch is gone and nothing can be rebuilt")
    func neitherMeansGone() {
        #expect(RestoreSource.of(hasLocalBranch: false, remoteRef: nil) == .gone)
        #expect(RestoreSource.of(hasLocalBranch: false, remoteRef: "") == .gone)
        #expect(RestoreSource.gone.canRebuild == false)
        #expect(RestoreSource.localBranch.canRebuild)
        #expect(RestoreSource.remoteBranch(ref: "refs/remotes/origin/x").canRebuild)
    }

    @Test("each fate says something different, and only the last one says work cannot resume")
    func explanations() {
        let sources: [RestoreSource] = [
            .localBranch, .remoteBranch(ref: "refs/remotes/origin/x"), .gone,
        ]
        let sentences = sources.map { $0.explanation(branch: "feature/x") }
        #expect(Set(sentences).count == 3)
        #expect(sentences.allSatisfy { $0.contains("feature/x") })
        #expect(sentences[2].contains("cannot be worked in again"))
        #expect(sentences[2].contains("still here to read"))
    }

    @Test("a free path is used as it is")
    func freePathIsLeftAlone() {
        #expect(WorktreePath.free(preferred: "/w/x") { _ in false } == "/w/x")
    }

    @Test("an occupied path counts up until it finds one that is free")
    func occupiedPathCountsUp() {
        let taken: Set<String> = ["/w/x", "/w/x-2", "/w/x-3"]
        #expect(WorktreePath.free(preferred: "/w/x") { taken.contains($0) } == "/w/x-4")
    }

    @Test("the suffix is the one new worktrees already use, so the two cannot drift apart")
    func theSuffixIsTheExistingOne() {
        #expect(WorktreePath.free(preferred: "/w/x") { $0 == "/w/x" } == "/w/x-2")
    }

    @Test("a worktree goes in one flat folder per project, whatever slashes the branch carries")
    func preferredPathIsFlatUnderTheProject() {
        let root = URL(fileURLWithPath: "/w")
        #expect(
            WorktreePath.preferred(branch: "dark-mode", project: "unifieddev", under: root)
                == "/w/unifieddev/dark-mode"
        )
        #expect(
            WorktreePath.preferred(branch: "freek/dark/mode", project: "unifieddev", under: root)
                == "/w/unifieddev/freek-dark-mode"
        )
    }

    @Test("uncommitted work is not restored, because nothing kept a copy of it")
    func uncommittedWorkStaysLost() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try TempRepo(existing: workspace.path).write("scratch.txt", "never committed\n")
        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: false, force: true
        )
        try await manager.restore(workspace: workspace, repo: registered)

        #expect(FileManager.default.fileExists(atPath: workspace.path))
        #expect(TempRepo(existing: workspace.path).exists("scratch.txt") == false)
    }

    @Test("commits on the branch do not stop a restore, because the branch still holds them")
    func commitsAreNotALoss() {
        let report = WorkspaceSafetyReport(unpushedCommits: 4)
        #expect(report.isSafeToDiscard == false)
        #expect(report.isRestorableFromBranch)
    }

    @Test("anything that lived only in the worktree stops a restore", arguments: [
        WorkspaceSafetyReport(hasUncommittedChanges: true),
        WorkspaceSafetyReport(untrackedFiles: ["notes.md"]),
        WorkspaceSafetyReport(modifiedIgnoredFiles: [".env"]),
        WorkspaceSafetyReport(detachedCommits: 2),
    ])
    func worktreeOnlyWorkBlocksARestore(report: WorkspaceSafetyReport) {
        #expect(report.isRestorableFromBranch == false)
    }

    @Test("an archive the report cleared outright is restorable")
    func aCleanReportIsRestorable() {
        let report = WorkspaceSafetyReport()
        #expect(report.isSafeToDiscard)
        #expect(report.isRestorableFromBranch)
    }

    @Test("a restored workspace says its setup has to be run again")
    func restoreAsksForSetupAgain() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [scripts]
        setup = "touch installed.txt"
        """)
        defer { repo.cleanUp() }

        let succeeded = await manager.runSetup(
            workspace: workspace, repo: registered, port: 0
        ) { _ in }
        #expect(succeeded)
        #expect(FileManager.default.fileExists(
            atPath: (workspace.path as NSString).appendingPathComponent("installed.txt")
        ))

        try await manager.archive(
            workspace: workspace, repo: registered, deleteBranch: false, force: true
        )
        let archived = try #require(try await manager.store.workspace(id: workspace.id))
        let outcome = try await manager.restore(workspace: archived, repo: registered)

        #expect(FileManager.default.fileExists(atPath: outcome.workspace.path))
        #expect(FileManager.default.fileExists(
            atPath: (outcome.workspace.path as NSString).appendingPathComponent("installed.txt")
        ) == false)

        #expect(outcome.workspace.setupState == .pending)
        #expect(outcome.workspace.setupLog.contains("Run setup again"))
    }

    @Test("a project with no setup script comes back skipped, not pending")
    func restoreWithNoSetupScript() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        let archived = try #require(try await manager.store.workspace(id: workspace.id))
        let outcome = try await manager.restore(workspace: archived, repo: registered)

        #expect(outcome.workspace.setupState == .skipped)
    }
}
