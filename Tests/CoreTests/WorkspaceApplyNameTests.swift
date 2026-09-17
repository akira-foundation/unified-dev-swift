import Testing
import Foundation
@testable import Core

@Suite("Applying an automatic name", .tags(.git, .destructive), .scratchDirectory)
struct WorkspaceApplyNameTests {
    private struct Fixture {
        let repo: TempRepo
        let store: Store
        let manager: WorkspaceManager
        let workspace: Workspace
        let placeholder: String
    }

    private func fixture(
        prompt: String = "Add a toggle to the settings screen",
        placeholder: String = "Foxglove"
    ) async throws -> Fixture {
        let repo = try await TempRepo()
        let store = try makeTestStore("apply")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(
            repo: registered, prompt: prompt, name: placeholder
        )
        return Fixture(
            repo: repo, store: store, manager: manager,
            workspace: workspace, placeholder: placeholder
        )
    }

    @Test("the name and the branch both move when nothing depends on the old branch")
    func renamesBoth() async throws {
        let fixture = try await self.fixture()
        defer { fixture.repo.cleanUp() }

        let result = try #require(try await fixture.manager.applyName(
            WorkspaceNameSuggestion(name: "Dark mode toggle", branch: "dark-mode-toggle"),
            to: fixture.workspace.id,
            placeholder: fixture.placeholder,
            hasPullRequest: false
        ))

        #expect(result.didRename)
        #expect(result.branchRefusal == nil)
        #expect(result.notice == nil)
        #expect(result.workspace.name == "Dark mode toggle")
        #expect(result.workspace.branch == "dark-mode-toggle")

        let stored = try #require(try await fixture.store.workspace(id: fixture.workspace.id))
        #expect(stored.branch == "dark-mode-toggle")
        #expect(try await Git.currentBranch(of: stored.path) == "dark-mode-toggle")

        #expect(stored.path == fixture.workspace.path)
        #expect(FileManager.default.fileExists(atPath: stored.path + "/README.md"))
    }

    @Test("a workspace the user renamed while the model was thinking keeps their name")
    func userNameWins() async throws {
        let fixture = try await self.fixture()
        defer { fixture.repo.cleanUp() }

        _ = try await fixture.store.upsert(fixture.workspace.with { $0.name = "My billing work" })

        let result = try #require(try await fixture.manager.applyName(
            WorkspaceNameSuggestion(name: "Dark mode toggle", branch: "dark-mode-toggle"),
            to: fixture.workspace.id,
            placeholder: fixture.placeholder,
            hasPullRequest: false
        ))

        #expect(!result.didRename)
        #expect(result.workspace.name == "My billing work")
        #expect(result.workspace.branch == fixture.workspace.branch)
        #expect(try await Git.currentBranch(of: fixture.workspace.path) == fixture.workspace.branch)
    }

    @Test("a branch with a commit on it keeps its name, and the user is told")
    func commitsKeepTheBranch() async throws {
        let fixture = try await self.fixture()
        defer { fixture.repo.cleanUp() }

        let worktree = TempRepo(existing: fixture.workspace.path)
        try worktree.write("toggle.swift", "// started\n")
        try await worktree.commit("start the toggle")

        let result = try #require(try await fixture.manager.applyName(
            WorkspaceNameSuggestion(name: "Dark mode toggle", branch: "dark-mode-toggle"),
            to: fixture.workspace.id,
            placeholder: fixture.placeholder,
            hasPullRequest: false
        ))

        #expect(result.didRename)
        #expect(result.workspace.name == "Dark mode toggle")
        #expect(result.workspace.branch == fixture.workspace.branch)
        #expect(result.branchRefusal == .hasCommits(1))

        let notice = try #require(result.notice)
        #expect(notice.contains("Dark mode toggle"))
        #expect(notice.contains(fixture.workspace.branch))
        #expect(notice.contains("1 commit"))

        #expect(await Git.branchExists(fixture.workspace.branch, in: fixture.repo.path))
        #expect(!(await Git.branchExists("dark-mode-toggle", in: fixture.repo.path)))
    }

    @Test("a pull request keeps the branch, and says so")
    func pullRequestKeepsTheBranch() async throws {
        let fixture = try await self.fixture()
        defer { fixture.repo.cleanUp() }

        let result = try #require(try await fixture.manager.applyName(
            WorkspaceNameSuggestion(name: "Dark mode toggle", branch: "dark-mode-toggle"),
            to: fixture.workspace.id,
            placeholder: fixture.placeholder,
            hasPullRequest: true
        ))

        #expect(result.branchRefusal == .hasPullRequest)
        #expect(result.workspace.branch == fixture.workspace.branch)
        #expect(result.notice?.contains("pull request") == true)
    }

    @Test("a suggestion with no usable branch still names the workspace, quietly")
    func nameWithoutBranch() async throws {
        let fixture = try await self.fixture()
        defer { fixture.repo.cleanUp() }

        let result = try #require(try await fixture.manager.applyName(
            WorkspaceNameSuggestion(name: "Dark mode toggle", branch: ""),
            to: fixture.workspace.id,
            placeholder: fixture.placeholder,
            hasPullRequest: false
        ))

        #expect(result.didRename)
        #expect(result.workspace.name == "Dark mode toggle")
        #expect(result.workspace.branch == fixture.workspace.branch)
        #expect(result.branchRefusal == .noValidName)
        #expect(result.notice == nil)
    }

    @Test("a branch the user renamed by hand is never taken back")
    func handRenamedBranch() async throws {
        let fixture = try await self.fixture()
        defer { fixture.repo.cleanUp() }

        try await Git.renameBranch(
            fixture.workspace.branch, to: "my-own-branch", in: fixture.workspace.path
        )

        let result = try #require(try await fixture.manager.applyName(
            WorkspaceNameSuggestion(name: "Dark mode toggle", branch: "dark-mode-toggle"),
            to: fixture.workspace.id,
            placeholder: fixture.placeholder,
            hasPullRequest: false
        ))

        #expect(result.branchRefusal == .renamedByHand("my-own-branch"))
        #expect(try await Git.currentBranch(of: fixture.workspace.path) == "my-own-branch")
        #expect(result.notice?.contains("my-own-branch") == true)
    }

    @Test("a workspace that is no longer in the store is not an error")
    func missingWorkspace() async throws {
        let fixture = try await self.fixture()
        defer { fixture.repo.cleanUp() }

        let result = try await fixture.manager.applyName(
            WorkspaceNameSuggestion(name: "Dark mode", branch: "dark-mode"),
            to: WorkspaceID("no-such-workspace"),
            placeholder: fixture.placeholder,
            hasPullRequest: false
        )
        #expect(result == nil)
    }
}
