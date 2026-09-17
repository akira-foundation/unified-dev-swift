import Testing
import Foundation
@testable import Core

@Suite("Workspace archiving", .tags(.git, .destructive), .scratchDirectory)
struct WorkspaceArchiveTests {
    private func makeWorkspace(
        settings: String? = nil,
        prompt: String = "Archive safety"
    ) async throws -> (repo: TempRepo, registered: Repo, manager: WorkspaceManager, workspace: Workspace) {
        let repo = try await TempRepo()
        if let settings { try repo.write(".conductor/settings.toml", settings) }
        let manager = WorkspaceManager(store: try makeTestStore("archive"))
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

    @Test("delete_branch_on_archive drives branch deletion when the caller says nothing")
    func settingDrivesBranchDeletion() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [git]
        delete_branch_on_archive = true
        """)
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered)
        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
    }

    @Test("an explicit false beats a settings file that says delete")
    func explicitArgumentBeatsTheSetting() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [git]
        delete_branch_on_archive = true
        """)
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
    }

    @Test("a settings file asking for deletion cannot skip the safety report")
    func settingCannotBypassTheReport() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [git]
        delete_branch_on_archive = true
        """)
        defer { repo.cleanUp() }

        try TempRepo(existing: workspace.path).write("feature.txt", "only copy\n")
        try await commit(in: workspace.path, message: "only copy")
        let sha = try await Git.headSHA(of: workspace.path)

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered)
        }
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
        #expect(FileManager.default.fileExists(atPath: workspace.path + "/feature.txt"))
        let reachable = try await Shell.run("git", ["cat-file", "-e", "\(sha)^{commit}"], cwd: repo.path)
        #expect(reachable.ok)
    }

    @Test("force does not skip the archive script, so a failed wind-down still stops everything")
    func forceDoesNotSkipTheArchiveScript() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [scripts]
        archive = 'exit 9'
        """)
        defer { repo.cleanUp() }

        let error = await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered, force: true)
        }
        guard case .archiveScriptFailed(let status, _)? = error else {
            Issue.record("expected archiveScriptFailed, got \(String(describing: error))")
            return
        }
        #expect(status == 9)
        #expect(FileManager.default.fileExists(atPath: workspace.path))
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
        #expect(try await manager.store.workspace(id: workspace.id)?.state != .archived)
    }

    @Test("the archive script is handed the same port the setup script was")
    func theArchiveScriptSeesTheWorkspacePort() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [scripts]
        archive = 'printf %s "$UD_PORT" > "$UD_ROOT_PATH/archived-on-port"; printf %s "$CONDUCTOR_PORT" > "$UD_ROOT_PATH/archived-on-alias"'
        """)
        defer { repo.cleanUp() }

        let port = await manager.ensurePort(for: workspace)
        #expect(port != 0)

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)

        let written = try String(contentsOfFile: repo.path + "/archived-on-port", encoding: .utf8)
        #expect(written == String(port))
        let alias = try String(contentsOfFile: repo.path + "/archived-on-alias", encoding: .utf8)
        #expect(alias == String(port))
    }

    @Test("the archive reads the port from the row rather than from the value handed to it")
    func theArchivePortComesFromTheRow() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [scripts]
        archive = 'printf %s "$UD_PORT" > "$UD_ROOT_PATH/archived-on-port"'
        """)
        defer { repo.cleanUp() }

        let port = await manager.ensurePort(for: workspace)
        #expect(workspace.port == 0)

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)

        let written = try String(contentsOfFile: repo.path + "/archived-on-port", encoding: .utf8)
        #expect(written == String(port))
    }

    @Test("an archive script is given long enough for a real teardown")
    func theArchiveScriptBudgetFitsARealTeardown() {
        #expect(WorkspaceManager.archiveScriptTimeout >= .seconds(300))
    }

    @Test("an archive script that runs past its budget is killed and the archive abandoned")
    func anOverrunningArchiveScriptStopsTheArchive() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [scripts]
        archive = 'sleep 120'
        """)
        defer { repo.cleanUp() }

        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(
                workspace: workspace, repo: registered, archiveScriptTimeout: .seconds(1)
            )
        }

        #expect(FileManager.default.fileExists(atPath: workspace.path))
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
        #expect(try await manager.store.workspace(id: workspace.id)?.state != .archived)
    }

    @Test("a refusal is not sticky: cleaning the worktree makes the same workspace archivable")
    func refusalIsNotSticky() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("scratch.txt", "throwaway\n")
        await #expect(throws: WorkspaceError.self) {
            try await manager.archive(workspace: workspace, repo: registered)
        }

        try FileManager.default.removeItem(atPath: workspace.path + "/scratch.txt")
        #expect(worktree.exists("scratch.txt") == false)

        try await manager.archive(workspace: workspace, repo: registered)
        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
    }

    @Test("a worktree somebody already deleted by hand still archives cleanly")
    func archivesAWorktreeThatIsAlreadyGone() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try FileManager.default.removeItem(atPath: workspace.path)

        try await manager.archive(workspace: workspace, repo: registered)
        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
        #expect(try await Git.worktrees(of: repo.path).count == 1)
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
    }

    @Test("an unrecognized folder archives while preserving its files and branch",
          arguments: [false, true], [false, true])
    func archivesAnUnrecognizedFolder(force: Bool, prune: Bool) async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace(settings: """
        [git]
        delete_branch_on_archive = true
        [scripts]
        archive = 'touch "$UD_ROOT_PATH/archive-script-ran"; exit 9'
        """)
        defer { repo.cleanUp() }
        defer { try? FileManager.default.removeItem(atPath: workspace.path) }

        try TempRepo(existing: workspace.path).write("feature.txt", "committed work\n")
        try await commit(in: workspace.path, message: "keep this branch")
        let sha = try await Git.headSHA(of: workspace.path)
        try FileManager.default.removeItem(atPath: workspace.path)
        if prune {
            try await Shell.check("git", ["worktree", "prune"], cwd: repo.path)
        }
        try FileManager.default.createDirectory(atPath: workspace.path, withIntermediateDirectories: true)
        let folder = TempRepo(existing: workspace.path)
        try folder.write("notes.txt", "only remaining copy\n")

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.preservedFolderPath == workspace.path)
        #expect(report.isSafeToDiscard)
        #expect(!report.isRestorableFromBranch)

        try await manager.archive(workspace: workspace, repo: registered, force: force)

        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
        #expect(folder.read("notes.txt") == "only remaining copy\n")
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
        let branchSHA = try await Shell.check("git", ["rev-parse", workspace.branch], cwd: repo.path)
        #expect(branchSHA.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == sha)
        #expect(!repo.exists("archive-script-ran"))

        let restored = try await manager.restore(workspace: workspace, repo: registered)
        defer { try? FileManager.default.removeItem(atPath: restored.workspace.path) }
        #expect(restored.workspace.state == .active)
        #expect(restored.workspace.path != workspace.path)
        #expect(try await Git.headSHA(of: restored.workspace.path) == sha)
        #expect(folder.read("notes.txt") == "only remaining copy\n")

        try repo.write(".conductor/settings.toml", "")
        try await manager.archive(workspace: restored.workspace, repo: registered, deleteBranch: false)
        let restoredAgain = try await manager.restore(workspace: restored.workspace, repo: registered)
        try await manager.archive(workspace: restoredAgain.workspace, repo: registered, deleteBranch: true, force: true)
        #expect(!(await Git.branchExists(workspace.branch, in: repo.path)))
        #expect(folder.read("notes.txt") == "only remaining copy\n")
    }

    @Test("restoring a retained folder cannot override another live checkout")
    func retainedFolderDoesNotOverrideLiveCheckout() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }
        defer { try? FileManager.default.removeItem(atPath: workspace.path) }
        try FileManager.default.removeItem(atPath: workspace.path)
        try FileManager.default.createDirectory(atPath: workspace.path, withIntermediateDirectories: true)
        try await manager.archive(workspace: workspace, repo: registered)

        let livePath = workspace.path + "-live"
        defer { try? FileManager.default.removeItem(atPath: livePath) }
        try await Shell.check("git", ["worktree", "add", "--force", "--", livePath, workspace.branch], cwd: repo.path)
        try TempRepo(existing: livePath).write("notes.txt", "live work\n")

        await #expect(throws: ShellError.self) {
            try await manager.restore(workspace: workspace, repo: registered)
        }
        #expect(TempRepo(existing: livePath).read("notes.txt") == "live work\n")
        #expect(try await manager.store.workspace(id: workspace.id)?.state == .archived)
    }

    @Test("forcing over a dirty worktree destroys exactly what the report listed")
    func forceDestroysOnlyWhatWasReported() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("README.md", "edited\n")
        try worktree.write("notes.txt", "untracked\n")

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.losses.count == 2)

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true, force: true)
        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
        #expect(repo.read("README.md") == "hello\n")
        #expect(await Git.branchExists("main", in: repo.path))
    }

    @Test("an ignored file the agent edited is destroyed without the report mentioning it")
    func ignoredFilesAreInvisibleToTheReport() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".gitignore", ".env\n")
        try await repo.commit("ignore env")
        try repo.write(".env", "APP_KEY=from-the-main-checkout\n")

        let manager = WorkspaceManager(store: try makeTestStore("archive"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Edit the env")

        let worktree = TempRepo(existing: workspace.path)
        #expect(worktree.read(".env") == "APP_KEY=from-the-main-checkout\n")
        try worktree.write(".env", "APP_KEY=the-agent-worked-this-out\nQUEUE=redis\n")

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.isSafeToDiscard == false, "an edited .env is work that exists nowhere else")

        let refused: Bool
        do {
            try await manager.archive(workspace: workspace, repo: registered)
            refused = false
        } catch {
            refused = true
            #expect(
                refused || FileManager.default.fileExists(atPath: workspace.path + "/.env"),
                "archiving destroyed the edited .env without ever reporting it as a loss"
            )
        }
    }

    @Test("commits made on a detached HEAD in the worktree are invisible to the report")
    func detachedHeadCommitsAreInvisibleToTheReport() async throws {
        let (repo, registered, manager, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await Shell.check("git", ["checkout", "-q", "--detach"], cwd: workspace.path)
        try TempRepo(existing: workspace.path).write("detached.txt", "work on no branch\n")
        try await commit(in: workspace.path, message: "detached work")
        let sha = try await Git.headSHA(of: workspace.path)

        let report = try await manager.safetyReport(workspace: workspace, repo: registered)
        #expect(report.detachedCommits >= 1, "the detached commit exists nowhere else")
        #expect(report.isSafeToDiscard == false)

        let refused: Bool
        do {
            try await manager.archive(workspace: workspace, repo: registered)
            refused = false
        } catch {
            refused = true
        }

        let reachable = try await Shell.run("git", ["rev-list", "--all"], cwd: repo.path)
        #expect(
            refused || reachable.stdout.contains(sha),
            "archiving left the detached commit reachable from nothing"
        )
    }
}
