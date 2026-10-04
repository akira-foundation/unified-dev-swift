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

    @Test("a path rather than a folder name is refused")
    func refusesAPath() {
        #expect(!scenario(["/tmp/harbour"]).problems.isEmpty)
        #expect(!scenario([".hidden"]).problems.isEmpty)
    }
}
