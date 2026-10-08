import Foundation
import Testing
@testable import Core

@Suite("A scenario that fills a worktree with untracked files")
struct PreviewScenarioSpareFilesTests {
    private func scenario(_ value: String) throws -> PreviewScenario {
        let json = Data("""
            {"projects":[{"name":"atlas","workspaces":[
              {"name":"One","branch":"one","spareFiles":\(value)}
            ]}]}
            """.utf8)
        return try JSONDecoder().decode(PreviewScenario.self, from: json)
    }

    @Test("the count is read")
    func readsTheCount() throws {
        #expect(try scenario("2000").projects[0].workspaces[0].spareFiles == 2_000)
    }

    @Test("a workspace that says nothing seeds nothing")
    func defaultsToNone() throws {
        let json = Data("""
            {"projects":[{"name":"atlas","workspaces":[{"name":"One","branch":"one"}]}]}
            """.utf8)
        let read = try JSONDecoder().decode(PreviewScenario.self, from: json)

        #expect(read.projects[0].workspaces[0].spareFiles == 0)
        #expect(read.problems.isEmpty)
    }

    @Test("a count the preview can seed is not a problem")
    func acceptsTheCeiling() throws {
        #expect(try scenario("4000").problems.isEmpty)
    }

    @Test("a count above the ceiling is a problem, not a frozen preview")
    func refusesTooMany() throws {
        #expect(try scenario("40000").problems.contains { $0.contains("spareFiles") })
    }

    @Test("a negative count is a problem too")
    func refusesNegative() throws {
        #expect(try scenario("-1").problems.contains { $0.contains("spareFiles") })
    }

    @Test("the names the seeder writes are distinct paths inside the worktree", arguments: [1, 3, 2_000])
    func theNamesAreUsable(count: Int) {
        let names = PreviewScenario.Workspace.spareFileNames(count)

        #expect(names.count == count)
        #expect(Set(names).count == count)
        for name in names {
            #expect(PreviewScenario.isRelativeFile(name), "\(name)")
        }
    }

    @Test("asking for none gives none rather than trapping", arguments: [0, -1])
    func noneIsEmpty(count: Int) {
        #expect(PreviewScenario.Workspace.spareFileNames(count).isEmpty)
    }
}
