import Foundation
import Testing
@testable import Core

@Suite("A scenario that seeds the folders opened recently")
struct PreviewScenarioRecentTests {
    private func scenario(_ recent: [String]) -> PreviewScenario {
        PreviewScenario(
            projects: [PreviewScenario.Project(name: "harbour")],
            looseRepositories: ["almanac"],
            looseFolders: ["sketches"],
            recentFolders: recent
        )
    }

    @Test("a scenario names no recent folders by default")
    func noneByDefault() throws {
        let read = try PreviewScenario.read(Data(#"{"projects":[{"name":"harbour"}]}"#.utf8))

        #expect(read.recentFolders.isEmpty)
    }

    @Test("a project, a loose repository and a loose folder may all be named")
    func acceptsEveryKindOfFolder() {
        #expect(scenario(["harbour", "almanac", "sketches"]).problems.isEmpty)
    }

    @Test("a folder the scenario never makes is refused, rather than seeded as a missing path")
    func refusesAFolderItNeverMakes() {
        let problems = scenario(["ghost"]).problems

        #expect(problems.count == 1)
        #expect(problems[0].contains("\"ghost\""))
    }

    @Test("the same folder named twice is refused")
    func refusesARepeat() {
        #expect(scenario(["harbour", "harbour"]).problems.count == 1)
    }

    @Test("a path rather than a folder name is refused as a name, and says so")
    func refusesAPath() {
        let slashed = scenario(["/tmp/harbour"]).problems
        let dotted = scenario([".hidden"]).problems

        #expect(slashed.contains { $0.contains("is not a plain folder name") })
        #expect(dotted.contains { $0.contains("is not a plain folder name") })
    }
}

@Suite(
    "Seeding the folders a preview has opened recently",
    .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1))
)
struct PreviewScenarioRecentSeedingTests {
    @Test("the folders are stored in the order the scenario names them, newest first")
    func storesTheOrderTheScenarioNames() async throws {
        let root = TestScratch.unique("preview-recent")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-recent"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(
            manager: manager, scratchRoot: PreviewIdentity.scratch(in: root)
        )

        let outcome = try await seeder.seed(PreviewScenario(
            projects: [PreviewScenario.Project(name: "harbour")],
            looseRepositories: ["almanac"],
            looseFolders: ["sketches"],
            recentFolders: ["sketches", "harbour", "almanac"]
        ))

        #expect(outcome.recentFolders == 3)

        let stored = await DirectoryPreferences.storedFolders(in: manager.store)

        #expect(stored == [
            seeder.looseRoot + "/sketches",
            seeder.projectsRoot + "/harbour",
            seeder.looseRoot + "/almanac",
        ])
    }

    @Test("a project is resolved under the projects root, and a loose folder under the loose root")
    func resolvesEachKindUnderItsOwnRoot() async throws {
        let root = TestScratch.unique("preview-recent")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-recent-roots"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(
            manager: manager, scratchRoot: PreviewIdentity.scratch(in: root)
        )

        _ = try await seeder.seed(PreviewScenario(
            projects: [PreviewScenario.Project(name: "harbour")],
            looseFolders: ["sketches"],
            recentFolders: ["harbour", "sketches"]
        ))

        let stored = await DirectoryPreferences.storedFolders(in: manager.store)

        #expect(stored.first == seeder.projectsRoot + "/harbour")
        #expect(stored.last == seeder.looseRoot + "/sketches")
        #expect(stored.allSatisfy { FolderPath.exists($0) })
    }
}
