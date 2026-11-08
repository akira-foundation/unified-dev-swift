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

    @Test("a project written for a profile that is gone lands in Unified")
    func orphanedProjectLandsInInitial() async throws {
        let store = try makeTestStore("profiles-orphan")
        let gone = try await store.createProfile(name: "Gone", colour: Accent.all[1], symbol: "star")
        try await store.deleteProfile(id: gone.id)
        let written = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo"), profileID: gone.id))
        #expect(written.profileID == .initial)
        #expect(try await store.repo(id: written.id)?.profileID == .initial)
    }

    @Test("a new profile does not take a folder already in the workspaces root")
    func occupiedFolderIsSkipped() async throws {
        let store = try makeTestStore("profiles-occupied")
        let profile = try await store.createProfile(
            name: "Unified Dev", colour: Accent.all[1], symbol: "star", occupiedFolders: ["unified-dev"]
        )
        #expect(profile.folder == "unified-dev-2")
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

    @Test("the refusal answers from the profile and its project count")
    func deletionRefusalRule() {
        #expect(ProfileDeletionRefused.refusal(for: .initial, projectCount: 0) == .initial)
        #expect(ProfileDeletionRefused.refusal(for: .initial, projectCount: 3) == .initial)
        #expect(ProfileDeletionRefused.refusal(for: ProfileID("a"), projectCount: 2) == .hasProjects(count: 2))
        #expect(ProfileDeletionRefused.refusal(for: ProfileID("a"), projectCount: 0) == nil)
    }

    @Test("the refusal explains itself with the number of projects")
    func deletionRefusalSentence() {
        #expect(ProfileDeletionRefused.hasProjects(count: 1).sentence == "This profile still has 1 project. Move it to another profile first.")
        #expect(ProfileDeletionRefused.hasProjects(count: 2).sentence == "This profile still has 2 projects. Move them to another profile first.")
    }

    @Test("a profile cannot take the unified folder")
    func reservedFolder() async throws {
        let store = try makeTestStore("profiles-reserved")
        let other = try await store.createProfile(name: "Unified", colour: Accent.all[1], symbol: "star")
        #expect(other.folder == "unified-2")
    }

    @Test("a renamed Unified keeps its name, and its folder, when the store is reopened")
    func renamedInitialSurvivesReopening() async throws {
        let path = TestScratch.unique("profiles-renamed") + ".sqlite"
        let first = try Store(path: path)
        try await first.update(profileID: .initial) { $0.name = "Personal" }

        let reopened = try Store(path: path)

        let profile = try #require(try await reopened.profile(id: .initial))
        #expect(profile.name == "Personal")
        #expect(profile.folder == ProfileID.initial.rawValue)
        #expect(try await reopened.profiles().count == 1)
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
            path: TestScratch.unique("old"), baseBranch: "main", state: .archived,
            archivedAt: Date(timeIntervalSince1970: 1_000_000)
        ))
        let reposBefore = try await seeding.repos()
        let workspacesBefore = try await seeding.workspaces(repoID: repo.id, includeArchived: true)

        let raw = try SQLiteDatabase(path: path)
        let version = try raw.readUserVersion()
        try raw.execute("DROP TABLE profiles;")
        try raw.execute("ALTER TABLE repos DROP COLUMN profile_id;")
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)

        #expect(try await reopened.repos() == reposBefore)
        #expect(try await reopened.repos().map(\.profileID) == [.initial])
        #expect(try await reopened.workspaces(repoID: repo.id, includeArchived: true) == workspacesBefore)
        #expect(workspacesBefore.contains { $0.isOrchestrator })
        #expect(workspacesBefore.contains { $0.state == .archived })
        #expect(try await reopened.profiles().map(\.id) == [.initial])
        #expect(try raw.readUserVersion() == version)

        let akira = try await reopened.createProfile(name: "Akira", colour: Accent.all[2], symbol: "a.circle")
        try await reopened.move(repoID: repo.id, to: akira.id)
        #expect(try await reopened.repo(id: repo.id)?.profileID == akira.id)
    }
}
