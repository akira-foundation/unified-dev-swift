import Testing
import Foundation
@testable import Core

@Suite("WorkspaceManager", .tags(.git), .scratchDirectory)
struct WorkspaceManagerTests {
    @Test("registers a repository once, and finds its default branch")
    func registersRepository() async throws {
        let repo = try await TempRepo(defaultBranch: "main")
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("wm"))

        let added = try await manager.addRepository(at: repo.path)
        #expect(added.defaultBranch == "main")
        #expect(added.accent == Accent.all[0])

        let again = try await manager.addRepository(at: repo.path)
        #expect(again.id == added.id)
        #expect(try await manager.store.repos().count == 1)
    }

    @Test("refuses a folder that is not a repository")
    func refusesNonRepository() async throws {
        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let plain = TestScratch.unique("unifieddev-plain")
        try FileManager.default.createDirectory(atPath: plain, withIntermediateDirectories: true)

        let error = await #expect(throws: WorkspaceError.self) {
            try await manager.addRepository(at: plain)
        }
        guard case .notARepository? = error else {
            Issue.record("expected notARepository, got \(String(describing: error))")
            return
        }
    }

    @Test("creates a worktree, a branch and a persisted workspace from a prompt")
    func createsWorkspace() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("wm")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)

        let workspace = try await manager.createWorkspace(
            repo: registered,
            prompt: "Stop the silent field clear when a value is missing"
        )

        #expect(workspace.branch == "stop-silent-field-clear-when")
        #expect(workspace.name == "Stop the silent field clear when a value is missing")
        #expect(workspace.baseBranch == "main")
        #expect(FileManager.default.fileExists(atPath: workspace.path + "/README.md"))

        let worktrees = try await Git.worktrees(of: repo.path)
        #expect(worktrees.contains { $0.branch == workspace.branch })

        #expect(try await store.workspaces().map(\.id) == [workspace.id])
    }

    @Test("does not collide when two workspaces derive the same branch name")
    func avoidsBranchCollisions() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let registered = try await manager.addRepository(at: repo.path)

        let first = try await manager.createWorkspace(repo: registered, prompt: "Fix the flaky test")
        let second = try await manager.createWorkspace(repo: registered, prompt: "Fix the flaky test")

        #expect(first.branch == "fix-flaky-test")
        #expect(second.branch == "fix-flaky-test-2")
        #expect(first.path != second.path)
    }

    @Test("two creates at the same moment get two different worktrees")
    func avoidsBranchCollisionsUnderConcurrency() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let registered = try await manager.addRepository(at: repo.path)

        let created = try await withThrowingTaskGroup(of: Workspace.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    try await manager.createWorkspace(repo: registered, prompt: "Fix the flaky test")
                }
            }
            var all: [Workspace] = []
            for try await workspace in group { all.append(workspace) }
            return all
        }

        #expect(Set(created.map(\.branch)).count == 4)
        #expect(Set(created.map(\.path)).count == 4)
        for workspace in created {
            #expect(FileManager.default.fileExists(atPath: workspace.path))
        }
    }

    @Test("creates in two different projects do not queue behind each other")
    func differentRepositoriesDoNotQueue() async throws {
        let first = try await TempRepo()
        defer { first.cleanUp() }
        let second = try await TempRepo()
        defer { second.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let one = try await manager.addRepository(at: first.path)
        let two = try await manager.addRepository(at: second.path)

        async let a = manager.createWorkspace(repo: one, prompt: "Do the thing")
        async let b = manager.createWorkspace(repo: two, prompt: "Do the thing")
        let (left, right) = try await (a, b)

        #expect(left.branch == "do-thing")
        #expect(right.branch == "do-thing")
        #expect(left.path != right.path)
    }

    @Test("copies the configured files into a new worktree")
    func copiesFiles() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        try repo.write(".env", "APP_ENV=local\n")
        try repo.write(".env.testing", "APP_ENV=testing\n")
        try repo.write("secret.key", "shh\n")

        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Copy env files")

        let worktree = TempRepo(existing: workspace.path)
        #expect(worktree.read(".env") == "APP_ENV=local\n")
        #expect(worktree.read(".env.testing") == "APP_ENV=testing\n")
        #expect(worktree.exists("secret.key") == false)
    }

    @Test("honours a repo's settings file for the branch prefix and copied files")
    func honoursRepoSettings() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        try repo.write(".conductor/settings.toml", """
        files_to_copy = [".env*", "secret.key"]

        [git]
        branch_prefix = "freek"
        """)
        try repo.write("secret.key", "shh\n")
        try repo.write(".env", "x\n")

        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Use the settings file")

        #expect(workspace.branch == "freek/use-settings-file")
        #expect(workspace.path.contains("freek/use") == false)
        #expect(workspace.path.hasSuffix("freek-use-settings-file"))

        let worktree = TempRepo(existing: workspace.path)
        #expect(worktree.exists("secret.key"))
        #expect(worktree.exists(".env"))
    }

    @Test("runs the setup script with the workspace environment exported", .tags(.subprocess))
    func runsSetupScript() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = '''
        echo "name=$CONDUCTOR_WORKSPACE_NAME"
        echo "root=$UD_ROOT_PATH"
        echo "port=$UD_PORT"
        echo "local=$CONDUCTOR_IS_LOCAL"
        touch setup-ran.txt
        '''
        """)

        let store = try makeTestStore("wm")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Run setup")

        #expect(workspace.setupState == .pending)

        let collector = LineCollector()
        let succeeded = await manager.runSetup(
            workspace: workspace, repo: registered, port: 3_100
        ) { collector.append($0) }

        #expect(succeeded)
        let output = collector.joined
        #expect(output.contains("name=run-setup"))
        #expect(output.contains("root="))
        #expect(output.contains(URL(fileURLWithPath: repo.path).lastPathComponent))
        #expect(output.contains("port=3100"))
        #expect(output.contains("local=1"))

        let worktree = TempRepo(existing: workspace.path)
        #expect(worktree.exists("setup-ran.txt"))
        #expect(try await store.workspace(id: workspace.id)?.setupState == .succeeded)
    }

    @Test("a setup script can say where this workspace's browser panes open", .tags(.subprocess))
    func setupScriptStatesTheBrowserAddress() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = '''
        echo "https://$UD_PROJECT_NAME.test" > "$UD_URL_FILE"
        '''
        """)

        let store = try makeTestStore("wm")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Say where")

        let succeeded = await manager.runSetup(
            workspace: workspace, repo: registered, port: 3_100
        ) { _ in }
        #expect(succeeded)

        let environment = manager.environment(for: workspace, repo: registered, port: 3_100)
        let address = WorkspaceBrowserURL.read(
            worktree: workspace.path,
            settings: SettingsLoader.load(repo: repo.path),
            environment: environment,
            port: 3_100
        )
        #expect(address == "https://\(WorkspaceManager.projectName(for: registered)).test")

        let worktree = TempRepo(existing: workspace.path)
        #expect(worktree.exists(WorkspaceBrowserURL.file))
        #expect(environment["CONDUCTOR_URL_FILE"] == environment["UD_URL_FILE"])
    }

    @Test("records a failing setup script rather than pretending it worked", .tags(.subprocess))
    func recordsFailingSetup() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = '''
        echo "about to fail"
        exit 7
        '''
        """)

        let store = try makeTestStore("wm")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Fail setup")

        let succeeded = await manager.runSetup(workspace: workspace, repo: registered, port: 0) { _ in }
        #expect(succeeded == false)

        let stored = try await store.workspace(id: workspace.id)
        #expect(stored?.setupState == .failed)
        #expect(stored?.setupLog.contains("about to fail") == true)
    }

    @Test(
        "cancelling a setup run stops the script and files it as stopped",
        .tags(.subprocess), .timeLimit(.minutes(2))
    )
    func cancellingSetupStopsTheScript() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = '''
        trap '' TERM
        echo "seeding"
        for _ in $(seq 1 1200); do sleep 0.05; done
        touch finished.txt
        '''
        """)

        let store = try makeTestStore("wm")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Stop setup")

        let collector = LineCollector()
        let run = Task {
            await manager.runSetup(workspace: workspace, repo: registered, port: 0) { collector.append($0) }
        }
        await waitUntil("the script has printed its first line") {
            collector.joined.contains("seeding")
        }

        run.cancel()
        let succeeded = await run.value
        #expect(succeeded == false)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.setupState == .failed)
        #expect(stored.setupLog.contains("seeding"))
        #expect(stored.setupLog.contains(WorkspaceManager.setupStoppedNote))
        #expect(!TempRepo(existing: workspace.path).exists("finished.txt"), Comment(rawValue: stored.setupLog))
    }

    @Test(
        "a finishing setup run does not undo edits made while it ran",
        .tags(.subprocess), .timeLimit(.minutes(1))
    )
    func setupDoesNotClobberConcurrentEdits() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = '''
        for _ in $(seq 1 600); do
          [ -f "$UD_WORKSPACE_PATH/go" ] && exit 0
          sleep 0.05
        done
        exit 1
        '''
        """)

        let store = try makeTestStore("wm")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Slow setup")

        let run = Task {
            await manager.runSetup(workspace: workspace, repo: registered, port: 0) { _ in }
        }
        await waitUntil("the setup run has marked the workspace running") {
            (try? await store.workspace(id: workspace.id))??.setupState == .running
        }

        try await store.update(workspaceID: workspace.id) {
            $0.name = "renamed while setup ran"
            $0.pinned = true
        }

        let worktree = TempRepo(existing: workspace.path)
        try worktree.write("go", "")

        #expect(await run.value)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.setupState == .succeeded)
        #expect(stored.name == "renamed while setup ran")
        #expect(stored.pinned)
    }

    @Test("archiving removes the worktree and runs the archive script", .tags(.destructive))
    func archivesWorkspace() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".conductor/settings.toml", """
        [scripts]
        archive = 'echo archived > "$UD_ROOT_PATH/archive-marker.txt"'
        """)

        let store = try makeTestStore("wm")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Archive me")

        try await manager.archive(workspace: workspace, repo: registered)

        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(repo.exists("archive-marker.txt"))
        #expect(try await store.workspace(id: workspace.id)?.state == .archived)
        #expect(try await store.workspaces().isEmpty)
        #expect(await Git.branchExists(workspace.branch, in: repo.path))
    }

    @Test("archiving can delete the branch when asked", .tags(.destructive))
    func archivesAndDeletesBranch() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Delete my branch")

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: true)
        #expect(await Git.branchExists(workspace.branch, in: repo.path) == false)
    }

    @Test("matches copy patterns the way a shell glob would", arguments: [
        (".env", ".env*", true),
        (".env.local", ".env*", true),
        ("env", ".env*", false),
        ("secret.key", "secret.key", true),
        ("secret.key2", "secret.key", false),
        ("a.txt", "?.txt", true),
        ("ab.txt", "?.txt", false),
    ])
    func matchesGlobs(name: String, pattern: String, expected: Bool) {
        #expect(FilesToCopyResolver.matches(name, pattern: pattern) == expected)
    }

    private func cloneWithRemoteBranch(_ branch: String) async throws -> (TempRepo, TempRepo) {
        let upstream = try await TempRepo()
        try await Shell.check("git", ["checkout", "-q", "-b", branch], cwd: upstream.path)
        try upstream.write("mcp.txt", "figma\n")
        try await upstream.commit("add the check")
        try await Shell.check("git", ["checkout", "-q", "main"], cwd: upstream.path)

        let clonePath = TestScratch.unique("unifieddev-git")
        try await Shell.check("git", ["clone", "-q", upstream.path, clonePath], cwd: upstream.path)
        return (upstream, TempRepo(existing: clonePath))
    }

    @Test("opens a branch that lives only on the remote, and the diff is against the default branch")
    func opensRemoteOnlyBranch() async throws {
        let (upstream, clone) = try await cloneWithRemoteBranch("figma-mcp-check")
        defer { upstream.cleanUp(); clone.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let registered = try await manager.addRepository(at: clone.path)

        let workspace = try await manager.createWorkspace(
            repo: registered,
            prompt: "have a look",
            checkout: .branch(ExistingBranch(name: "figma-mcp-check", isLocal: false))
        )

        #expect(workspace.branch == "figma-mcp-check")
        #expect(workspace.name == "figma-mcp-check")
        #expect(workspace.baseBranch == "main")
        let stat = try await Git.diffStat(worktree: workspace.path, base: workspace.baseBranch)
        #expect(stat.files == 1)

        let upstreamRef = try await Shell.check(
            "git", ["rev-parse", "--abbrev-ref", "figma-mcp-check@{upstream}"], cwd: workspace.path
        )
        #expect(upstreamRef.trimmed == "origin/figma-mcp-check")
    }

    @Test("opens a branch the picker called remote but that is already local, under its own name")
    func opensBranchAlreadyFetched() async throws {
        let (upstream, clone) = try await cloneWithRemoteBranch("figma-mcp-check")
        defer { upstream.cleanUp(); clone.cleanUp() }
        try await Shell.check(
            "git", ["branch", "figma-mcp-check", "origin/figma-mcp-check"], cwd: clone.path
        )
        let manager = WorkspaceManager(store: try makeTestStore("wm"))
        let registered = try await manager.addRepository(at: clone.path)

        let workspace = try await manager.createWorkspace(
            repo: registered,
            prompt: "have a look",
            checkout: .branch(ExistingBranch(name: "figma-mcp-check", isLocal: false))
        )

        #expect(workspace.branch == "figma-mcp-check")
        let worktrees = try await Git.worktrees(of: clone.path)
        #expect(worktrees.contains { $0.branch == "figma-mcp-check" && $0.path == workspace.path })
    }
}
