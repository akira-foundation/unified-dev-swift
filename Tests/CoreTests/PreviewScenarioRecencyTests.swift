import Foundation
import Testing
@testable import Core

@Suite("A scenario that says when a workspace was last worked in")
struct PreviewScenarioRecencyTests {
    private func scenario(_ workspace: String) throws -> PreviewScenario {
        let json = Data("""
            {"projects":[{"name":"atlas","workspaces":[\(workspace)]}]}
            """.utf8)
        return try JSONDecoder().decode(PreviewScenario.self, from: json)
    }

    @Test("a workspace with no lastActive names no moment of its own")
    func noLastActiveIsNoMoment() throws {
        let read = try scenario(#"{"name":"One","branch":"one"}"#)

        #expect(read.projects[0].workspaces[0].lastActive == nil)
        #expect(read.projects[0].workspaces[0].lastActiveMoment(from: Date()) == nil)
    }

    @Test("lastActive is read as hours ago")
    func readsHoursAgo() throws {
        let read = try scenario(#"{"name":"One","branch":"one","lastActive":48}"#)

        #expect(read.projects[0].workspaces[0].lastActive == 48)
        #expect(read.problems.isEmpty)
    }

    @Test("hours ago is counted back from the moment of seeding")
    func countsBackFromSeeding() throws {
        let read = try scenario(#"{"name":"One","branch":"one","lastActive":48}"#)
        let now = Date(timeIntervalSince1970: 1_000_000)

        #expect(read.projects[0].workspaces[0].lastActiveMoment(from: now)
            == Date(timeIntervalSince1970: 1_000_000 - 48 * 3_600))
    }

    @Test("a negative lastActive is a problem the launcher reports rather than a date in the future")
    func refusesTheFuture() throws {
        let read = try scenario(#"{"name":"One","branch":"one","lastActive":-3}"#)

        #expect(read.problems.contains { $0.contains("lastActive") })
    }

    @Test("a scenario with a negative lastActive is refused outright, and says why")
    func refusedOnRead() throws {
        let json = Data("""
            {"projects":[{"name":"atlas","workspaces":[
              {"name":"One","branch":"one","lastActive":-3}
            ]}]}
            """.utf8)

        let thrown = #expect(throws: PreviewScenarioError.self) {
            try PreviewScenario.read(json)
        }

        guard case .invalid(let problems) = thrown else {
            Issue.record("expected the scenario to be refused as invalid, not as unreadable")
            return
        }
        #expect(problems.contains { $0.contains("lastActive") })
    }

    @Test("a workspace worked in now is a problem nobody has, because zero is allowed")
    func zeroIsAllowed() throws {
        let read = try scenario(#"{"name":"One","branch":"one","lastActive":0}"#)

        #expect(read.problems.isEmpty)
    }

    @Test("the shipped scenario still demonstrates recency, one project per rule")
    func theShippedScenarioStillDemonstratesRecency() throws {
        let read = try TestScenarios.shipped("recent-projects")
        let byName = Dictionary(uniqueKeysWithValues: read.projects.map { ($0.name, $0) })

        let kestrel = try #require(byName["kestrel"])
        let atlas = try #require(byName["atlas"])
        let harbour = try #require(byName["harbour"])
        let quay = try #require(byName["quay"])
        let secret = try #require(byName["secret"])

        #expect(kestrel.workspaces.compactMap(\.lastActive) == [20])
        #expect(atlas.workspaces.compactMap(\.lastActive) == [170])
        #expect(quay.workspaces.isEmpty)
        #expect(secret.hidden)
        #expect(secret.workspaces.contains { ($0.lastActive ?? .infinity) < 2 })

        let started = try #require(harbour.workspaces.first { $0.startedBy != nil })
        #expect(started.lastActive == 0.5)
        #expect(harbour.workspaces.filter { $0.startedBy == nil }
            .allSatisfy { ($0.lastActive ?? 0) > kestrel.workspaces[0].lastActive ?? 0 })
    }
}

@Suite("Seeding a workspace worked in before the seeding", .tags(.git, .subprocess), .scratchDirectory,
       .timeLimit(.minutes(1)))
struct PreviewScenarioRecencySeedingTests {
    @Test("the row holds the moment the scenario asked for, counted back from the seeding")
    func storesTheMoment() async throws {
        let root = TestScratch.unique("preview-recency")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-recency"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        let now = Date(timeIntervalSince1970: 2_000_000)

        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "ledger", workspaces: [
                PreviewScenario.Workspace(name: "Old", branch: "old", lastActive: 48),
                PreviewScenario.Workspace(name: "Fresh", branch: "fresh"),
            ]),
        ]), at: now)

        let repo = try #require(try await manager.store.repos().first)
        let workspaces = try await manager.store.workspaces(repoID: repo.id)
        let old = try #require(workspaces.first { $0.branch == "old" })
        let fresh = try #require(workspaces.first { $0.branch == "fresh" })

        #expect(old.lastActivityAt == now.addingTimeInterval(-48 * 3_600))
        #expect(fresh.lastActivityAt > old.lastActivityAt)
        #expect(try await manager.store.projectActivity()[repo.id] == fresh.lastActivityAt)
    }

    @Test("two workspaces an hour apart in the scenario are an hour apart in the store")
    func keepsTheGap() async throws {
        let root = TestScratch.unique("preview-recency-gap")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-recency-gap"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))

        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "ledger", workspaces: [
                PreviewScenario.Workspace(name: "First", branch: "first", lastActive: 2),
                PreviewScenario.Workspace(name: "Second", branch: "second", lastActive: 1),
            ]),
        ]), at: Date(timeIntervalSince1970: 3_000_000))

        let repo = try #require(try await manager.store.repos().first)
        let workspaces = try await manager.store.workspaces(repoID: repo.id)
        let first = try #require(workspaces.first { $0.branch == "first" })
        let second = try #require(workspaces.first { $0.branch == "second" })

        #expect(second.lastActivityAt.timeIntervalSince(first.lastActivityAt) == 3_600)
    }
}
