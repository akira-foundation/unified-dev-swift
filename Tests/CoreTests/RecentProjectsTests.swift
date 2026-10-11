import Foundation
import Testing
@testable import Core

@Suite("The projects worked in most recently")
struct RecentProjectsTests {
    private func repo(_ name: String, hidden: Bool = false) -> Repo {
        Repo(name: name, path: "/tmp/\(name)", hidden: hidden)
    }

    private func at(_ hoursAgo: Double) -> Date {
        Date(timeIntervalSince1970: 1_000_000 - hoursAgo * 3_600)
    }

    @Test("the most recently worked in project comes first")
    func mostRecentFirst() {
        let old = repo("atlas")
        let fresh = repo("harbour")
        let ordered = RecentProjects.ordered(
            [old, fresh], activity: [old.id: at(40), fresh.id: at(1)]
        )

        #expect(ordered.map(\.name) == ["harbour", "atlas"])
    }

    @Test("a project nobody has worked in is not recent at all")
    func noActivityIsNotRecent() {
        let worked = repo("atlas")
        let untouched = repo("harbour")
        let ordered = RecentProjects.ordered([worked, untouched], activity: [worked.id: at(2)])

        #expect(ordered.map(\.name) == ["atlas"])
    }

    @Test("a hidden project is never offered as recent, however recently it was used")
    func hiddenIsNeverRecent() {
        let hidden = repo("secret", hidden: true)
        let plain = repo("atlas")
        let ordered = RecentProjects.ordered(
            [hidden, plain], activity: [hidden.id: at(1), plain.id: at(10)]
        )

        #expect(ordered.map(\.name) == ["atlas"])
    }

    @Test("no more than the limit comes back, and it is the newest end of the list")
    func respectsTheLimit() {
        let repos = (1...15).map { repo("p\($0)") }
        var activity: [RepoID: Date] = [:]
        for (index, repo) in repos.enumerated() { activity[repo.id] = at(Double(15 - index)) }

        let ordered = RecentProjects.ordered(repos, activity: activity, limit: 10)

        #expect(ordered.count == 10)
        #expect(ordered.first?.name == "p15")
        #expect(!ordered.contains { $0.name == "p1" })
    }

    @Test("two projects last used at the same moment are ordered by name")
    func tiesGoByName() {
        let second = repo("harbour")
        let first = repo("atlas")
        let same = at(3)
        let ordered = RecentProjects.ordered([second, first], activity: [second.id: same, first.id: same])

        #expect(ordered.map(\.name) == ["atlas", "harbour"])
    }

    @Test("ten is the limit when the caller does not say otherwise")
    func tenByDefault() {
        let repos = (1...15).map { repo("p\($0)") }
        var activity: [RepoID: Date] = [:]
        for (index, repo) in repos.enumerated() { activity[repo.id] = at(Double(15 - index)) }

        #expect(RecentProjects.ordered(repos, activity: activity).count == RecentProjects.limit)
        #expect(RecentProjects.limit == 10)
    }
}

@Suite("Project activity, read from the store", .tags(.persistence), .scratchDirectory)
struct ProjectActivityStoreTests {
    @Test("the newest workspace activity in a project is the project's activity")
    func newestWins() async throws {
        let store = try makeTestStore("activity")
        let repo = Repo(name: "atlas", path: TestScratch.path("atlas"))
        try await store.upsert(repo)
        let older = Workspace(
            repoID: repo.id, name: "Old", branch: "old", path: TestScratch.path("old"),
            baseBranch: "main", lastActivityAt: Date(timeIntervalSince1970: 10)
        )
        let newer = Workspace(
            repoID: repo.id, name: "New", branch: "new", path: TestScratch.path("new"),
            baseBranch: "main", lastActivityAt: Date(timeIntervalSince1970: 90)
        )
        try await store.upsert(older)
        try await store.upsert(newer)

        let activity = try await store.projectActivity()

        #expect(activity[repo.id] == Date(timeIntervalSince1970: 90))
    }

    @Test("an archived workspace still counts, because working in it was still working in the project")
    func archivedCounts() async throws {
        let store = try makeTestStore("activity-archived")
        let repo = Repo(name: "atlas", path: TestScratch.path("atlas-2"))
        try await store.upsert(repo)
        let archived = Workspace(
            repoID: repo.id, name: "Gone", branch: "gone", path: TestScratch.path("gone"),
            baseBranch: "main", state: .archived,
            lastActivityAt: Date(timeIntervalSince1970: 50),
            archivedAt: Date(timeIntervalSince1970: 60)
        )
        try await store.upsert(archived)

        let activity = try await store.projectActivity()

        #expect(activity[repo.id] == Date(timeIntervalSince1970: 50))
    }

    @Test("a workspace an agent started does not make a project recent for the owner")
    func agentStartedDoesNotCount() async throws {
        let store = try makeTestStore("activity-agent")
        let repo = Repo(name: "atlas", path: TestScratch.path("atlas-3"))
        try await store.upsert(repo)
        let mine = Workspace(
            repoID: repo.id, name: "Mine", branch: "mine", path: TestScratch.path("mine"),
            baseBranch: "main", lastActivityAt: Date(timeIntervalSince1970: 10)
        )
        let theirs = Workspace(
            repoID: repo.id, name: "Theirs", branch: "theirs", path: TestScratch.path("theirs"),
            baseBranch: "main", lastActivityAt: Date(timeIntervalSince1970: 99),
            origin: .agent(parentWorkspaceID: mine.id, spawnToolUseID: "tool-1")
        )
        try await store.upsert(mine)
        try await store.upsert(theirs)

        let activity = try await store.projectActivity()

        #expect(activity[repo.id] == Date(timeIntervalSince1970: 10))
    }

    @Test("a workspace the owner started from his own client is the owner working there")
    func ownerClientCounts() async throws {
        let store = try makeTestStore("activity-owner-client")
        let repo = Repo(name: "atlas", path: TestScratch.path("atlas-5"))
        try await store.upsert(repo)
        let fromTheClient = Workspace(
            repoID: repo.id, name: "Client", branch: "client", path: TestScratch.path("client"),
            baseBranch: "main", lastActivityAt: Date(timeIntervalSince1970: 70),
            origin: .ownerClient(spawnToolUseID: "tool-2")
        )
        try await store.upsert(fromTheClient)

        let activity = try await store.projectActivity()

        #expect(activity[repo.id] == Date(timeIntervalSince1970: 70))
    }

    @Test("a project with no workspaces at all is simply absent")
    func absentWithoutWorkspaces() async throws {
        let store = try makeTestStore("activity-empty")
        let repo = Repo(name: "atlas", path: TestScratch.path("atlas-4"))
        try await store.upsert(repo)

        let activity = try await store.projectActivity()

        #expect(activity[repo.id] == nil)
    }
}
