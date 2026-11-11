import Testing
import Foundation
@testable import Core

@Suite("Every gh call and agent runs under its profile's GitHub login", .tags(.persistence), .scratchDirectory)
struct GitHubLoginRoutingTests {
    private func seed(_ store: Store, in profile: ProfileID) async throws -> (repo: Repo, workspace: Workspace) {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo"), profileID: profile))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "billing", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return (repo, workspace)
    }

    @Test func aNewProfileUsesUnifiedsLoginAndCanTakeItsOwn() async throws {
        let store = try makeTestStore("github-login")
        let debtges = try await store.createProfile(name: "Debtges", colour: Accent.all[1], symbol: "star")
        #expect(store.gitHubLogin(for: debtges.id) == .thisMac)

        try await store.setGitHubSource(.own, for: debtges.id)
        let login = store.gitHubLogin(for: debtges.id)
        let support = URL(filePath: store.path).deletingLastPathComponent()
        #expect(login.directory?.path == ProfileGitHubLogins.root(support: support).appending(path: debtges.id.rawValue).path)

        try await store.setGitHubSource(.own, for: .initial)
        #expect(store.gitHubLogin(for: .initial) == .thisMac)

        let reopened = try Store(path: store.path)
        #expect(reopened.gitHubLogin(for: debtges.id) == login)

        try await reopened.setGitHubSource(.inherits, for: debtges.id)
        #expect(reopened.gitHubLogin(for: debtges.id) == .thisMac)
    }

    @Test func aDatabaseFromBeforeGivesEveryProfileUnifiedsLogin() async throws {
        let first = try makeTestStore("github-login-before")
        let debtges = try await first.createProfile(name: "Debtges", colour: Accent.all[1], symbol: "star")
        let raw = try SQLiteDatabase(path: first.path)
        let version = try raw.readUserVersion()
        try raw.execute("ALTER TABLE profiles DROP COLUMN github_source;")
        try raw.setUserVersion(version - 1)

        let reopened = try Store(path: first.path)
        #expect(reopened.gitHubLogins().source(of: debtges.id) == .inherits)
        try await reopened.setGitHubSource(.own, for: debtges.id)
        #expect(reopened.gitHubLogins().source(of: debtges.id) == .own)
    }

    @Test func aWorktreeResolvesToItsProjectsProfile() async throws {
        let store = try makeTestStore("github-login-route")
        let debtges = try await store.createProfile(name: "Debtges", colour: Accent.all[1], symbol: "star")
        try await store.setGitHubSource(.own, for: debtges.id)
        let (repo, workspace) = try await seed(store, in: debtges.id)
        let (unifiedRepo, _) = try await seed(store, in: .initial)

        #expect(try await store.gitHubLogin(forDirectory: workspace.path) == store.gitHubLogin(for: debtges.id))
        #expect(try await store.gitHubLogin(forDirectory: repo.path + "/Sources") == store.gitHubLogin(for: debtges.id))
        #expect(try await store.gitHubLogin(forDirectory: unifiedRepo.path) == .thisMac)
        #expect(try await store.gitHubLogin(forDirectory: "/nowhere") == .thisMac)
    }

    @Test func ghRunsUnderTheLoginOfTheDirectoryItRunsIn() async throws {
        let own = GitHubLogin.profile(ProfileID("debtges"), directory: URL(filePath: "/support/GitHubLogins/debtges"))
        let worktree = TestScratch.unique("routed")
        let seen = LoginLog()
        _ = try await GitHub.$loginResolverOverride.withValue({ directory in directory == worktree ? own : nil }) {
            try await GitHub.$commandOverride.withValue({ _, _ in
                await seen.record(GitHub.login)
                return ShellResult(status: 0, stdout: "", stderr: "")
            }) {
                _ = try await GitHub.run("gh", ["api", "user"], cwd: worktree)
                _ = try await GitHub.run("gh", ["api", "rate_limit"], cwd: TestScratch.unique("elsewhere"))
                _ = try await GitHub.$login.withValue(.thisMac) {
                    try await GitHub.run("gh", ["api", "emojis"], cwd: worktree)
                }
            }
        }
        #expect(await seen.logins == [own, .thisMac, .thisMac])
    }

    @Test func signedInCheckAsksUnderTheLoginItIsGiven() async {
        let own = GitHubLogin.profile(ProfileID("debtges"), directory: URL(filePath: "/support/GitHubLogins/debtges"))
        let seen = LoginLog()
        let access = await Shell.$executableLookup.withValue({ _ in "/usr/local/bin/gh" }) {
            await GitHub.$commandOverride.withValue({ arguments, _ in
                await seen.record(GitHub.login)
                return ShellResult(status: arguments == ["auth", "status"] ? 1 : 0, stdout: "", stderr: "")
            }) {
                await GitHub.access(login: own)
            }
        }
        #expect(access == .signedOut)
        #expect(await seen.logins == [own])
    }

    @Test func aWorkspaceTerminalCarriesItsProfilesLogin() async throws {
        let store = try makeTestStore("github-login-terminal")
        let debtges = try await store.createProfile(name: "Debtges", colour: Accent.all[1], symbol: "star")
        let (repo, workspace) = try await seed(store, in: debtges.id)
        let manager = WorkspaceManager(store: store)

        #expect(manager.environment(for: workspace, repo: repo, port: 3000)["GH_CONFIG_DIR"] == nil)

        try await store.setGitHubSource(.own, for: debtges.id)
        let variables = manager.environment(for: workspace, repo: repo, port: 3000)
        #expect(variables["GH_CONFIG_DIR"] == store.gitHubLogin(for: debtges.id).directory?.path)
        #expect(variables["GH_TOKEN"] == "")
    }

    @Test func anAgentLaunchCarriesTheLoginAndDropsInheritedTokens() async throws {
        let (store, made) = try await LaunchAccountFixture.session(kind: .claudeCode)
        let own = GitHubLogin.profile(ProfileID("debtges"), directory: URL(filePath: "/support/GitHubLogins/debtges"))
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: made, store: store, segmentID: try await activeSegmentID(store, made),
            gitHub: own, inheritedEnvironment: ["GH_TOKEN": "inherited", "GITHUB_TOKEN": "inherited", "PATH": "/bin"]
        )
        let launch = await runner.launch()
        #expect(launch.environment["GH_CONFIG_DIR"] == "/support/GitHubLogins/debtges")
        #expect(launch.environment["GH_TOKEN"] == nil)
        #expect(launch.environment["GITHUB_TOKEN"] == nil)
    }
}

private actor LoginLog {
    private(set) var logins: [GitHubLogin?] = []

    func record(_ login: GitHubLogin?) {
        logins.append(login)
    }
}
