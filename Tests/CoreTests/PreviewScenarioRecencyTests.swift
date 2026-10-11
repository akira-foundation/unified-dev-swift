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

    @Test("a workspace with no lastActive is as recent as the seeding")
    func defaultsToNow() throws {
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

    @Test("a scenario with a negative lastActive is refused outright")
    func refusedOnRead() throws {
        let json = Data("""
            {"projects":[{"name":"atlas","workspaces":[
              {"name":"One","branch":"one","lastActive":-3}
            ]}]}
            """.utf8)

        #expect(throws: PreviewScenarioError.self) {
            try PreviewScenario.read(json)
        }
    }

    @Test("a workspace worked in now is a problem nobody has, because zero is allowed")
    func zeroIsAllowed() throws {
        let read = try scenario(#"{"name":"One","branch":"one","lastActive":0}"#)

        #expect(read.problems.isEmpty)
    }

    @Test("the shipped scenario holds one project for each rule of recency")
    func theShippedScenarioShowsEveryRule() throws {
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
