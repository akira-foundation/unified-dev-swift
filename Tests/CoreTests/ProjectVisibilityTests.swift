import Foundation
import Testing
@testable import Core

@Suite("Hidden projects")
struct ProjectVisibilityTests {
    private let ember = Repo(name: "ember", path: "/Users/me/dev/ember", sortOrder: 0)
    private let unifieddev = Repo(name: "unifieddev", path: "/Users/me/dev/unifieddev", sortOrder: 1, hidden: true)
    private let site = Repo(name: "site", path: "/Users/me/dev/site", sortOrder: 2)

    @Test("a hidden project is left out of the list unless it is asked for")
    func filtering() {
        #expect(ProjectVisibility.listed([ember, unifieddev, site], showingHidden: false).map(\.name)
            == ["ember", "site"])
        #expect(ProjectVisibility.listed([ember, unifieddev, site], showingHidden: true).map(\.name)
            == ["ember", "unifieddev", "site"])
    }

    @Test("shown hidden projects keep their place in the order rather than sinking")
    func orderIsUntouched() {
        let shown = ProjectVisibility.listed([ember, unifieddev, site], showingHidden: true)

        #expect(shown.map(\.id) == [ember.id, unifieddev.id, site.id])
    }

    @Test("the count is what the toggle says out loud")
    func counting() {
        #expect(ProjectVisibility.hiddenCount([ember, unifieddev, site]) == 1)
        #expect(ProjectVisibility.hiddenCount([ember, site]) == 0)
        #expect(ProjectVisibility.toggleTitle(hiddenCount: 1) == "Show 1 hidden project")
        #expect(ProjectVisibility.toggleTitle(hiddenCount: 4) == "Show 4 hidden projects")
    }

    @Test("the toggle is still offered, and drops the count, when nothing is hidden")
    func toggleWithNothingHidden() {
        #expect(ProjectVisibility.toggleTitle(hiddenCount: 0) == "Show hidden projects")
    }

    @Test("hiding the last visible project says how to get one back")
    func emptySidebarSaysWhatToDo() {
        let sentence = ProjectVisibility.remainingSentence(visible: 0)

        #expect(sentence.contains("Show hidden projects"))
        #expect(sentence.contains("project_unhide"))
        #expect(ProjectVisibility.remainingSentence(visible: 1).contains("1 project is still"))
    }
}

@Suite("Hidden projects, stored", .tags(.persistence), .scratchDirectory)
struct HiddenProjectStoreTests {
    @Test("hidden survives a round trip and defaults to showing")
    func roundTrip() async throws {
        let store = try makeTestStore("hidden-round-trip")
        let repo = try await store.upsert(Repo(name: "ember", path: "/tmp/ember"))
        #expect(!repo.hidden)

        _ = try await store.update(repoID: repo.id) { $0.hidden = true }

        #expect(try await store.repo(id: repo.id)?.hidden == true)
    }

    @Test("hiding a project writes nothing else, even from a stale copy of the row")
    func hidingIsIsolated() async throws {
        let store = try makeTestStore("hidden-isolated")
        let stale = try await store.upsert(Repo(name: "ember", path: "/tmp/ember"))

        _ = try await store.update(repoID: stale.id) { $0.name = "Ember" }
        _ = try await store.update(repoID: stale.id) {
            $0.iconPath = "/tmp/ember/icon.png"
            $0.iconSource = .chosen
        }
        _ = try await store.update(repoID: stale.id) { $0.hidden = true }

        let stored = try #require(try await store.repo(id: stale.id))
        #expect(stored.hidden)
        #expect(stored.name == "Ember")
        #expect(stored.iconPath == "/tmp/ember/icon.png")
    }

    @Test("a project written before the column existed reads as showing")
    func migration() async throws {
        let path = TestScratch.unique("hidden-migration") + ".sqlite"
        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "ember", path: "/tmp/ember"))
        _ = try await store.update(repoID: repo.id) { $0.hidden = true }

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        #expect(try await reopened.repo(id: repo.id)?.hidden == true)
        let fresh = try await reopened.upsert(Repo(name: "new", path: "/tmp/new"))
        #expect(!fresh.hidden)
    }
}

@Suite("A project that comes back")
struct ProjectReturnTests {
    @Test("a hidden project comes back and a showing one is left where it is")
    func theRule() {
        let hidden = Repo(name: "unifieddev", path: "/Users/me/dev/unifieddev", hidden: true)
        let showing = Repo(name: "ember", path: "/Users/me/dev/ember")

        #expect(ProjectVisibility.comesBack(hidden))
        #expect(!ProjectVisibility.comesBack(showing))
    }

    @Test("a project that is no longer in the database is not brought back")
    func aProjectThatHasGone() {
        #expect(!ProjectVisibility.comesBack(nil))
    }
}

@Suite("A project that comes back, written", .tags(.persistence), .scratchDirectory)
struct ProjectReturnStoreTests {
    @Test("the flag is cleared and no other column moves with it")
    func writesOneColumn() async throws {
        let store = try makeTestStore("comes-back")
        let manager = WorkspaceManager(store: store)
        let project = try await store.upsert(
            Repo(name: "unifieddev", path: "/tmp/unifieddev", sortOrder: 3, hidden: true)
        )
        _ = try await store.update(repoID: project.id) {
            $0.name = "Unified Dev"
            $0.iconPath = "/tmp/unifieddev/icon.png"
            $0.iconSource = .chosen
        }

        #expect(await manager.bringProjectBack(project.id))

        let stored = try #require(try await store.repo(id: project.id))
        #expect(!stored.hidden)
        #expect(stored.name == "Unified Dev")
        #expect(stored.iconPath == "/tmp/unifieddev/icon.png")
        #expect(stored.sortOrder == 3)
    }

    @Test("a project that is already showing is not written")
    func showingProjectIsLeftAlone() async throws {
        let store = try makeTestStore("comes-back-showing")
        let manager = WorkspaceManager(store: store)
        let project = try await store.upsert(Repo(name: "ember", path: "/tmp/ember"))

        #expect(await manager.bringProjectBack(project.id) == false)
        #expect(try await store.repo(id: project.id)?.hidden == false)
    }

    @Test("a project that is no longer stored is not brought back")
    func missingProjectIsNotWritten() async throws {
        let manager = WorkspaceManager(store: try makeTestStore("comes-back-missing"))

        #expect(await manager.bringProjectBack(RepoID.new()) == false)
    }
}

@Suite(
    "A project that comes back, in the routes that add a workspace",
    .tags(.git), .scratchDirectory
)
struct ProjectReturnRouteTests {
    private func makeManager(
        _ label: String
    ) async throws -> (repo: TempRepo, registered: Repo, manager: WorkspaceManager, store: Store) {
        let repo = try await TempRepo()
        let store = try makeTestStore(label)
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        return (repo, registered, manager, store)
    }

    @Test("starting a workspace in a hidden project brings it back, and says so")
    func startingBringsTheProjectBack() async throws {
        let (repo, registered, manager, store) = try await makeManager("comes-back-start")
        defer { repo.cleanUp() }
        _ = try await store.update(repoID: registered.id) { $0.hidden = true }

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered,
            prompt: "Fix the flaky test",
            origin: .ownerClient(spawnToolUseID: "toolu_1"),
            opensSession: false
        ))

        #expect(started.projectCameBack)
        #expect(try await store.repo(id: registered.id)?.hidden == false)
        #expect(ProjectVisibility.listed(try await store.repos(), showingHidden: false).count == 1)
        #expect(try await store.workspaces().map(\.id) == [started.workspace.id])
    }

    @Test("starting a workspace in a project that is showing reports nothing")
    func startingInAShowingProjectReportsNothing() async throws {
        let (repo, registered, manager, store) = try await makeManager("comes-back-start-showing")
        defer { repo.cleanUp() }

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Fix the flaky test", origin: .user, opensSession: false
        ))

        #expect(started.projectCameBack == false)
        #expect(try await store.repo(id: registered.id)?.hidden == false)
    }

    @Test(
        "restoring an archived workspace into a hidden project brings it back",
        .tags(.destructive)
    )
    func restoringBringsTheProjectBack() async throws {
        let (repo, registered, manager, store) = try await makeManager("comes-back-restore")
        defer { repo.cleanUp() }
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Archive me")

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        _ = try await store.update(repoID: registered.id) { $0.hidden = true }

        try await manager.restore(workspace: workspace, repo: registered)

        #expect(try await store.repo(id: registered.id)?.hidden == false)
        #expect(try await store.workspaces().contains { $0.id == workspace.id })
    }
}
