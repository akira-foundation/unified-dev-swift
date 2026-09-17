import Testing
import Foundation
@testable import Core

@Suite("Starting a workspace", .tags(.git), .scratchDirectory)
struct WorkspaceStartTests {
    private func makeManager() async throws -> (repo: TempRepo, registered: Repo, manager: WorkspaceManager, store: Store) {
        let repo = try await TempRepo()
        let store = try makeTestStore("start")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        return (repo, registered, manager, store)
    }

    @Test("a chat workspace arrives with its worktree, its branch and one session")
    func startsAChat() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Fix the flaky test", origin: .user
        ))

        #expect(started.workspace.branch == "fix-flaky-test")
        #expect(FileManager.default.fileExists(atPath: started.workspace.path))
        #expect(started.workspace.baseBranch == "main")

        let session = try #require(started.session)
        #expect(session.workspaceID == started.workspace.id)
        #expect(try await store.sessions(workspaceID: started.workspace.id).map(\.id) == [session.id])
    }

    @Test("a workspace that opens no chat has no session")
    func startsWithoutASession() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "poke about", origin: .user,
            branch: "scratch", name: "scratch", opensSession: false
        ))

        #expect(started.session == nil)
        #expect(started.workspace.name == "scratch")
        #expect(started.workspace.branch == "scratch")
        #expect(try await store.sessions(workspaceID: started.workspace.id).isEmpty)
    }

    @Test("a terminal workspace started with nothing written takes the name it was handed")
    func startsWithNothingWritten() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(
            WorkspaceStartRequest(
                repo: registered, prompt: "", origin: .user,
                branch: "coral-sea", name: "Coral Sea", opensSession: false
            ),
            namer: { "Foxglove" }
        )

        #expect(started.workspace.name == "Coral Sea")
        #expect(started.workspace.branch == "coral-sea")
        #expect(started.placeholder == nil)
        #expect(started.session == nil)
        #expect(FileManager.default.fileExists(atPath: started.workspace.path))
        #expect(try await store.sessions(workspaceID: started.workspace.id).isEmpty)
    }

    @Test("nothing written and no name handed over still cuts a worktree")
    func startsWithNothingAtAll() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "", origin: .user, opensSession: false
        ))

        #expect(started.workspace.name == "New workspace")
        #expect(started.workspace.branch == "workspace")
        #expect(FileManager.default.fileExists(atPath: started.workspace.path))
        #expect(try await store.sessions(workspaceID: started.workspace.id).isEmpty)
    }

    @Test("the chosen backend, model, effort and permission mode reach the session row")
    func carriesTheControls() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Do the thing", origin: .user,
            controls: ComposerControls(
                model: "gpt-5-codex", effort: "high", agentKind: .codex,
                permissionMode: .acceptEdits, isFastMode: true, outputStyle: "Concise", codexFastMode: false
            )
        ))

        let session = try #require(started.session)
        #expect(session.model == "gpt-5-codex")
        #expect(session.effort == "high")
        #expect(session.agentKind == .codex)
        #expect(session.permissionMode == .acceptEdits)
        #expect(try await store.setting(CodexSpeed.key(sessionID: session.id)) == "0")

        #expect(
            try await store.setting(ComposerControls.fastModeKey(sessionID: session.id)) == "1"
        )
        #expect(
            try await store.setting(ComposerControls.outputStyleKey(sessionID: session.id)) == "Concise"
        )
        #expect(
            try await store.setting(ComposerControls.defaultsAppliedKey(sessionID: session.id)) == "1"
        )
    }

    @Test("no controls means the app-wide defaults, and no session is marked settled")
    func fallsBackToTheDefaults() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Do the thing", origin: .user
        ))

        let session = try #require(started.session)
        #expect(session.model == AppDefaults.fallbackModel)
        #expect(session.effort == AppDefaults.fallbackEffort)
        #expect(session.agentKind == .claudeCode)
        #expect(
            try await store.setting(ComposerControls.defaultsAppliedKey(sessionID: session.id)) == nil
        )
    }

    @Test("a base branch and a branch name are used as given")
    func usesTheGivenBranches() async throws {
        let (repo, registered, manager, _) = try await makeManager()
        defer { repo.cleanUp() }

        try await Shell.check("git", ["checkout", "-q", "-b", "develop"], cwd: repo.path)
        try repo.write("on-develop.txt", "yes\n")
        try await repo.commit("develop only")
        try await Shell.check("git", ["checkout", "-q", "main"], cwd: repo.path)

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Carry on", origin: .user,
            baseBranch: "develop", branch: "chosen/branch"
        ))

        #expect(started.workspace.branch == "chosen/branch")
        #expect(started.workspace.baseBranch == "develop")
        #expect(
            FileManager.default.fileExists(
                atPath: (started.workspace.path as NSString).appendingPathComponent("on-develop.txt")
            )
        )
    }

    @Test("the codename the namer hands out is the name the row is created under")
    func usesThePlaceholder() async throws {
        let (repo, registered, manager, _) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(
            WorkspaceStartRequest(repo: registered, prompt: "Fix the flaky test", origin: .user),
            namer: { "Foxglove" }
        )

        #expect(started.workspace.name == "Foxglove")
        #expect(started.placeholder == "Foxglove")
    }

    @Test("a namer that declines leaves the title git would have given it")
    func fallsBackToTheTitle() async throws {
        let (repo, registered, manager, _) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(
            WorkspaceStartRequest(repo: registered, prompt: "Fix the flaky test", origin: .user),
            namer: { nil }
        )

        #expect(started.workspace.name == Git.title(from: "Fix the flaky test"))
        #expect(started.placeholder == nil)
    }

    @Test("a name in the request is never handed to the namer")
    func aGivenNameWins() async throws {
        let (repo, registered, manager, _) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await manager.start(
            WorkspaceStartRequest(
                repo: registered, prompt: "Fix the flaky test", origin: .user, name: "Invoices"
            ),
            namer: { Issue.record("the namer was asked about a workspace that already had a name"); return "Foxglove" }
        )

        #expect(started.workspace.name == "Invoices")
        #expect(started.placeholder == nil)
    }

    @Test("a workspace an agent asked for records which one, and which tool call")
    func recordsTheOrigin() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let parent = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "The parent", origin: .user
        ))
        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Do a piece of it",
            origin: .agent(parentWorkspaceID: parent.workspace.id, spawnToolUseID: "toolu_01")
        ))

        #expect(parent.workspace.origin == .user)
        #expect(
            started.workspace.origin
                == .agent(parentWorkspaceID: parent.workspace.id, spawnToolUseID: "toolu_01")
        )
        let stored = try #require(try await store.workspace(id: started.workspace.id))
        #expect(stored.origin.parentWorkspaceID == parent.workspace.id)
        #expect(try await store.countWorkspaces(startedBy: parent.workspace.id) == 1)
    }

    @Test("a caller that asks for setup gets it run, and its output")
    func runsSetupWhenAsked() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = '''
        echo installing
        touch installed.txt
        '''
        """)

        let lines = LineCollector()
        let started = try await manager.start(
            WorkspaceStartRequest(
                repo: registered, prompt: "Needs dependencies", origin: .user, setupPolicy: .run
            ),
            setupOutput: { lines.append($0) }
        )

        #expect(started.setupSucceeded == true)
        #expect(lines.joined.contains("installing"))
        #expect(
            FileManager.default.fileExists(
                atPath: (started.workspace.path as NSString).appendingPathComponent("installed.txt")
            )
        )
        let stored = try #require(try await store.workspace(id: started.workspace.id))
        #expect(stored.setupState == .succeeded)
    }

    @Test("the port the setup script is given is the port the row keeps")
    func recordsThePortSetupWasGiven() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = "echo port=$UD_PORT"
        """)

        let lines = LineCollector()
        let started = try await manager.start(
            WorkspaceStartRequest(
                repo: registered, prompt: "Needs a port", origin: .user, setupPolicy: .run
            ),
            setupOutput: { lines.append($0) }
        )

        let stored = try #require(try await store.workspace(id: started.workspace.id))
        #expect(stored.port >= 3_100)
        #expect(lines.joined.contains("port=\(stored.port)"))
    }

    @Test("a setup script that fails is reported rather than thrown")
    func reportsAFailedSetup() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = "exit 3"
        """)

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Will not install", origin: .user, setupPolicy: .run
        ))

        #expect(started.setupSucceeded == false)
        #expect(FileManager.default.fileExists(atPath: started.workspace.path))
        #expect(started.session != nil)
        let stored = try #require(try await store.workspace(id: started.workspace.id))
        #expect(stored.setupState == .failed)
    }

    @Test("a caller that did not ask for setup is told nothing about it")
    func saysNothingAboutSetupItDidNotRun() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        try repo.write(".conductor/settings.toml", """
        [scripts]
        setup = "exit 3"
        """)

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Someone else will run it", origin: .user
        ))

        #expect(started.setupSucceeded == nil)
        let stored = try #require(try await store.workspace(id: started.workspace.id))
        #expect(stored.setupState == .pending)
    }

    @Test("a repository that is not there throws rather than raising an alert")
    func throwsWhenTheRepositoryIsGone() async throws {
        let (repo, registered, manager, _) = try await makeManager()
        repo.cleanUp()

        await #expect(throws: (any Error).self) {
            try await manager.start(WorkspaceStartRequest(
                repo: registered, prompt: "Nothing to cut from", origin: .user
            ))
        }
    }

    @Test("two starts at the same moment both come back whole")
    func twoStartsAtOnce() async throws {
        let (repo, registered, manager, store) = try await makeManager()
        defer { repo.cleanUp() }

        let started = try await withThrowingTaskGroup(of: StartedWorkspace.self) { group in
            for index in 0..<3 {
                group.addTask {
                    try await manager.start(WorkspaceStartRequest(
                        repo: registered, prompt: "Fix the flaky test",
                        origin: .agent(
                            parentWorkspaceID: WorkspaceID("parent"), spawnToolUseID: "toolu_\(index)"
                        )
                    ))
                }
            }
            var all: [StartedWorkspace] = []
            for try await one in group { all.append(one) }
            return all
        }

        #expect(Set(started.map(\.workspace.branch)).count == 3)
        #expect(started.compactMap(\.session).count == 3)
        #expect(try await store.countWorkspaces(startedBy: WorkspaceID("parent")) == 3)
    }
}

@Suite("Which tab a new workspace opens on")
struct WorkspaceOpeningTabTests {
    private func scratchDefaults() -> UserDefaults {
        let suite = "unifieddev.tests.startmode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("only a start that is not a chat records anything")
    func onlyAgentlessStartsRecord() {
        let defaults = scratchDefaults()
        let id = WorkspaceID("w1")

        WorkspaceStartMode.record(.chat, workspaceID: id, defaults: defaults)
        #expect(defaults.object(forKey: WorkspaceStartMode.defaultsKey(workspaceID: id)) == nil)

        WorkspaceStartMode.record(.terminal, workspaceID: id, defaults: defaults)
        #expect(defaults.string(forKey: WorkspaceStartMode.defaultsKey(workspaceID: id)) == "terminal")

        WorkspaceStartMode.record(.browser, workspaceID: id, defaults: defaults)
        #expect(defaults.string(forKey: WorkspaceStartMode.defaultsKey(workspaceID: id)) == "browser")
    }

    @Test("the hint says which tab, not whether")
    func hintSaysWhich() {
        for mode in [WorkspaceStartMode.terminal, .browser, .claudeCLI, .codexCLI] {
            let defaults = scratchDefaults()
            let id = WorkspaceID("w1")
            WorkspaceStartMode.record(mode, workspaceID: id, defaults: defaults)

            #expect(WorkspaceStartMode.consumeOpeningTab(workspaceID: id, defaults: defaults) == mode)
        }
    }

    @Test("each mode names the pane it opens")
    func modesNameTheirPane() {
        #expect(WorkspaceStartMode.chat.pane == .chat)
        #expect(WorkspaceStartMode.terminal.pane == .terminal)
        #expect(WorkspaceStartMode.browser.pane == .browser)
    }

    @Test("the hint answers exactly once")
    func answersExactlyOnce() {
        let defaults = scratchDefaults()
        let id = WorkspaceID("w1")
        WorkspaceStartMode.record(.browser, workspaceID: id, defaults: defaults)

        #expect(WorkspaceStartMode.consumeOpeningTab(workspaceID: id, defaults: defaults) == .browser)
        #expect(WorkspaceStartMode.consumeOpeningTab(workspaceID: id, defaults: defaults) == nil)
        #expect(defaults.object(forKey: WorkspaceStartMode.defaultsKey(workspaceID: id)) == nil)
    }

    @Test("a workspace nobody recorded anything for opens on its chat")
    func unknownWorkspacesOpenOnChat() {
        #expect(WorkspaceStartMode.consumeOpeningTab(
            workspaceID: WorkspaceID("never-seen"), defaults: scratchDefaults()
        ) == nil)
    }

    @Test("an unreadable hint is nothing to do, and is cleared")
    func unreadableIsCleared() {
        let defaults = scratchDefaults()
        let id = WorkspaceID("w1")
        defaults.set("notes", forKey: WorkspaceStartMode.defaultsKey(workspaceID: id))

        #expect(WorkspaceStartMode.consumeOpeningTab(workspaceID: id, defaults: defaults) == nil)
        #expect(defaults.object(forKey: WorkspaceStartMode.defaultsKey(workspaceID: id)) == nil)
    }

    @Test("a terminal recorded by the previous build is still honoured, once")
    func legacyFlagIsHonoured() {
        let defaults = scratchDefaults()
        let id = WorkspaceID("w1")
        defaults.set(true, forKey: WorkspaceStartMode.legacyTerminalKey(workspaceID: id))

        #expect(WorkspaceStartMode.consumeOpeningTab(workspaceID: id, defaults: defaults) == .terminal)
        #expect(WorkspaceStartMode.consumeOpeningTab(workspaceID: id, defaults: defaults) == nil)
        #expect(defaults.object(
            forKey: WorkspaceStartMode.legacyTerminalKey(workspaceID: id)
        ) == nil)
    }

    @Test("two workspaces do not share the hint")
    func workspacesDoNotShare() {
        let defaults = scratchDefaults()
        WorkspaceStartMode.record(.terminal, workspaceID: WorkspaceID("a"), defaults: defaults)

        #expect(WorkspaceStartMode.consumeOpeningTab(
            workspaceID: WorkspaceID("b"), defaults: defaults
        ) == nil)
        #expect(WorkspaceStartMode.consumeOpeningTab(
            workspaceID: WorkspaceID("a"), defaults: defaults
        ) == .terminal)
    }
}
