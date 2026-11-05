import Testing
import Foundation
@testable import Core

@Suite("Profile store", .tags(.persistence), .scratchDirectory)
struct ProfileStoreTests {
    @Test("a fresh database has only the Unified profile")
    func initialProfile() async throws {
        let store = try makeTestStore("profiles-fresh")
        let profiles = try await store.profiles()
        #expect(profiles.map(\.id) == [.initial])
        #expect(profiles.first?.name == "Unified")
        #expect(profiles.first?.folder == "unified")
    }

    @Test("existing projects land in Unified and keep every other column")
    func migrationKeepsRows() async throws {
        let store = try makeTestStore("profiles-migrate")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo"), hidden: true))
        let stored = try #require(try await store.repo(id: repo.id))
        #expect(stored.profileID == .initial)
        #expect(stored.hidden)
    }

    @Test("updating a project keeps its profile")
    func updateKeepsProfile() async throws {
        let store = try makeTestStore("profiles-update")
        let debtges = try await store.createProfile(name: "Debtges", colour: Accent.all[1], symbol: "building.2")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo"), profileID: debtges.id))
        try await store.update(repoID: repo.id) { $0.collapsed = true }
        #expect(try await store.repo(id: repo.id)?.profileID == debtges.id)
    }

    @Test("a project moved to another profile stays there")
    func updateMovesProfile() async throws {
        let store = try makeTestStore("profiles-move")
        let debtges = try await store.createProfile(name: "Debtges", colour: Accent.all[1], symbol: "building.2")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let debtgesID = debtges.id
        try await store.update(repoID: repo.id) { $0.profileID = debtgesID }
        #expect(try await store.repo(id: repo.id)?.profileID == debtges.id)
    }

    @Test("Unified cannot be deleted, and nor can a profile with projects")
    func deletionRefusals() async throws {
        let store = try makeTestStore("profiles-delete")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[2], symbol: "a.circle")
        _ = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo"), profileID: akira.id))
        await #expect(throws: ProfileDeletionRefused.initial) { try await store.deleteProfile(id: .initial) }
        await #expect(throws: ProfileDeletionRefused.hasProjects(count: 1)) {
            try await store.deleteProfile(id: akira.id)
        }
    }

    @Test("a profile cannot take the unified folder")
    func reservedFolder() async throws {
        let store = try makeTestStore("profiles-reserved")
        let other = try await store.createProfile(name: "Unified", colour: Accent.all[1], symbol: "star")
        #expect(other.folder == "unified-2")
    }

    @Test("an active profile that is gone falls back to Unified")
    func activeFallback() async throws {
        let store = try makeTestStore("profiles-active")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[2], symbol: "a.circle")
        try await store.setActiveProfile(akira.id)
        try await store.deleteProfile(id: akira.id)
        #expect(try await store.activeProfileID() == .initial)
    }

    @Test("an active profile that exists is the one answered")
    func activeKept() async throws {
        let store = try makeTestStore("profiles-active-kept")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[2], symbol: "a.circle")
        try await store.setActiveProfile(akira.id)
        #expect(try await store.activeProfileID() == akira.id)
    }

    @Test("a new profile goes to the end of the order")
    func createdLast() async throws {
        let store = try makeTestStore("profiles-order")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[2], symbol: "a.circle")
        let debtges = try await store.createProfile(name: "Debtges", colour: Accent.all[1], symbol: "building.2")
        #expect(try await store.profiles().map(\.id) == [.initial, akira.id, debtges.id])
        #expect(try await store.profile(id: debtges.id)?.folder == "debtges")
    }

    @Test("an update changes the name and never the id or the folder")
    func updateKeepsIdentity() async throws {
        let store = try makeTestStore("profiles-rename")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[2], symbol: "a.circle")
        let renamed = try await store.update(profileID: akira.id) { profile in
            profile.name = "Akira Foundation"
            profile = Profile(id: ProfileID("other"), name: profile.name, folder: "other", colour: "c", symbol: "s")
        }
        let stored = try #require(try await store.profile(id: akira.id))
        #expect(renamed == stored)
        #expect(stored.name == "Akira Foundation")
        #expect(stored.folder == "akira")
        #expect(try await store.profile(id: ProfileID("other")) == nil)
    }

    @Test("a profile with no projects can be deleted")
    func deleteEmpty() async throws {
        let store = try makeTestStore("profiles-delete-empty")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[2], symbol: "a.circle")
        try await store.deleteProfile(id: akira.id)
        #expect(try await store.profiles().map(\.id) == [.initial])
    }

    @Test("a database from before profiles keeps every row and puts it all in Unified")
    func olderDatabaseMigrates() async throws {
        let path = TestScratch.unique("profiles-old") + ".sqlite"
        let seeding = try Store(path: path)
        let repo = try await seeding.upsert(Repo(name: "r", path: TestScratch.unique("repo"), collapsed: true))
        let lead = try await seeding.upsert(Workspace(
            repoID: repo.id, name: "lead", branch: "b/lead",
            path: TestScratch.unique("lead"), baseBranch: "main"
        ))
        try await seeding.setOrchestrator(true, workspaceID: lead.id)
        _ = try await seeding.upsert(Workspace(
            repoID: repo.id, name: "old", branch: "b/old",
            path: TestScratch.unique("old"), baseBranch: "main", state: .archived
        ))
        let reposBefore = try await seeding.repos()
        let workspacesBefore = try await seeding.workspaces(repoID: repo.id, includeArchived: true)

        let raw = try SQLiteDatabase(path: path)
        let version = try raw.readUserVersion()
        try raw.execute("DROP TABLE profiles;")
        try raw.execute("ALTER TABLE repos DROP COLUMN profile_id;")
        try raw.setUserVersion(version - 1)

        let reopened = try Store(path: path)

        #expect(try await reopened.repos() == reposBefore)
        #expect(try await reopened.repos().map(\.profileID) == [.initial])
        #expect(try await reopened.workspaces(repoID: repo.id, includeArchived: true) == workspacesBefore)
        #expect(workspacesBefore.contains { $0.isOrchestrator })
        #expect(workspacesBefore.contains { $0.state == .archived })
        #expect(try await reopened.profiles().map(\.id) == [.initial])
        #expect(try raw.readUserVersion() == version)
    }
}
