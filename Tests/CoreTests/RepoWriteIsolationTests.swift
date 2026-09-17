import Testing
import Foundation
@testable import Core

@Suite("Project write isolation", .tags(.persistence), .scratchDirectory)
struct RepoWriteIsolationTests {
    private func seed(_ store: Store) async throws -> Repo {
        try await store.upsert(Repo(
            name: "unifieddev", path: TestScratch.unique("project"), defaultBranch: "main", accent: "4C8DF6"
        ))
    }

    @Test("changing the colour does not undo the icon that was just found")
    func accentDoesNotEraseTheIcon() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)

        try await store.update(repoID: repo.id) {
            $0.iconPath = "/projects/unifieddev/public/favicon.png"
            $0.iconSource = .detected
        }
        try await store.update(repoID: repo.id) { $0.accent = "FF3B30" }

        let stored = try #require(try await store.repo(id: repo.id))
        #expect(stored.accent == "FF3B30")
        #expect(stored.iconPath == "/projects/unifieddev/public/favicon.png")
        #expect(stored.iconSource == .detected)
        #expect(stored.hasIcon)
    }

    @Test("choosing an icon does not undo a rename made while the panel was open")
    func iconWriteDoesNotUndoARename() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)

        try await store.update(repoID: repo.id) { $0.name = "Unified Dev" }
        try await store.update(repoID: repo.id) {
            $0.iconPath = "/pictures/mark.svg"
            $0.iconSource = .chosen
        }

        let stored = try #require(try await store.repo(id: repo.id))
        #expect(stored.name == "Unified Dev")
        #expect(stored.iconSource == .chosen)
    }

    @Test("a write leaves alone every column it did not name")
    func writeTouchesOnlyWhatItNames() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)

        try await store.update(repoID: repo.id) { $0.name = "renamed" }
        try await store.update(repoID: repo.id) { $0.accent = "34C759" }
        try await store.update(repoID: repo.id) { $0.collapsed = true }
        try await store.update(repoID: repo.id) {
            $0.iconPath = "/p/icon.png"
            $0.iconSource = .detected
        }

        let stored = try #require(try await store.repo(id: repo.id))
        #expect(stored.name == "renamed")
        #expect(stored.accent == "34C759")
        #expect(stored.collapsed)
        #expect(stored.iconPath == "/p/icon.png")
        #expect(stored.iconSource == .detected)
        #expect(stored.path == repo.path)
        #expect(stored.defaultBranch == "main")
        #expect(abs(stored.createdAt.timeIntervalSince(repo.createdAt)) < 0.001)
    }

    @Test("asking for the monogram back is not undone by the next write")
    func monogramSurvives() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)

        try await store.update(repoID: repo.id) {
            $0.iconPath = "/p/icon.png"
            $0.iconSource = .detected
        }
        try await store.update(repoID: repo.id) {
            $0.iconPath = nil
            $0.iconSource = .monogram
        }
        try await store.update(repoID: repo.id) { $0.collapsed.toggle() }

        let stored = try #require(try await store.repo(id: repo.id))
        #expect(stored.iconPath == nil)
        #expect(stored.iconSource == .monogram)
        #expect(stored.hasIcon == false)
    }

    @Test("a toggle is against the stored value, not against the caller's copy")
    func toggleIsAgainstTheStoredValue() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)

        try await store.update(repoID: repo.id) { $0.collapsed.toggle() }
        try await store.update(repoID: repo.id) { $0.collapsed.toggle() }

        #expect(try await store.repo(id: repo.id)?.collapsed == false)
    }

    @Test("a targeted write does not recreate a project that is gone")
    func doesNotRecreateADeletedProject() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)
        try await store.deleteRepo(id: repo.id)

        let result = try await store.update(repoID: repo.id) { $0.name = "back from the dead" }

        #expect(result == nil)
        #expect(try await store.repos().isEmpty)
    }

    @Test("a write cannot change which project it is")
    func cannotChangeIdentity() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)

        try await store.update(repoID: repo.id) {
            $0.id = RepoID("some-other-id")
            $0.name = "renamed"
        }

        let stored = try #require(try await store.repo(id: repo.id))
        #expect(stored.id == repo.id)
        #expect(stored.name == "renamed")
        #expect(try await store.repos().count == 1)
    }

    @Test("a whole-value write from a copy read earlier loses whatever landed since")
    func wholeValueWriteIsWhyUpdateExists() async throws {
        let store = try makeTestStore("repo-isolation")
        let repo = try await seed(store)
        let held = repo

        try await store.update(repoID: repo.id) {
            $0.iconPath = "/p/icon.png"
            $0.iconSource = .detected
        }
        try await store.upsert(held.with { $0.accent = "FF3B30" })

        let stored = try #require(try await store.repo(id: repo.id))
        #expect(stored.accent == "FF3B30")
        #expect(stored.iconPath == nil)
        #expect(stored.iconSource == .undetected)
    }
}
