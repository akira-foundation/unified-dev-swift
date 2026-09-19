import Testing
import Foundation
@testable import Core

@Suite("A preview scenario that leaves changes in a workspace")
struct PreviewScenarioChangesTests {
    @Test("a workspace reads its changes, with an empty or null value meaning a deletion, and none by default")
    func readsTheChanges() throws {
        let scenario = try PreviewScenario.read(Data(#"""
            {"projects":[{"name":"a","workspaces":[
              {"name":"w","branch":"w","changes":{"src/new.txt":"fresh\n","old.txt":null,"gone.txt":""}},
              {"name":"v","branch":"v"}]}]}
            """#.utf8))
        let workspaces = scenario.projects[0].workspaces
        #expect(workspaces[0].changes == ["src/new.txt": "fresh\n", "old.txt": nil, "gone.txt": ""])
        #expect(workspaces[1].changes.isEmpty)
    }

    @Test("a change outside the worktree or inside its git folder is refused before anything is made", arguments: [
        "/etc/hosts", "src/../../x", ".git/config", "src/.GIT/hooks/x", "",
    ])
    func refusesAPathOutsideTheWorktree(path: String) {
        let scenario = PreviewScenario(projects: [
            PreviewScenario.Project(name: "a", workspaces: [
                PreviewScenario.Workspace(name: "w", branch: "w", changes: [path: "x"]),
            ]),
        ])
        #expect(scenario.problems.contains { $0.contains("which is not a path inside the worktree") })
    }
}

@Suite("Seeding a scenario's uncommitted changes", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioChangesSeedingTests {
    private func makeSeeder() throws -> PreviewScenarioSeeder {
        let root = TestScratch.unique("preview-changes")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-changes"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        return PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
    }

    private func status(in path: String) async throws -> [String] {
        try await Shell.check("git", ["status", "--porcelain", "--untracked-files=all"], cwd: path).stdout
            .split(separator: "\n").map(String.init).sorted()
    }

    @Test("changes are written into the worktree after it is cut and left uncommitted, deletions included")
    func leavesTheChangesUncommitted() async throws {
        let seeder = try makeSeeder()
        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(
                name: "ledger",
                files: ["kept.txt": "one\n", "old.txt": "old\n", "gone.txt": "gone\n"],
                workspaces: [
                    PreviewScenario.Workspace(name: "Review", branch: "review", changes: [
                        "kept.txt": "two\n", "src/new.txt": "fresh\n", "old.txt": nil, "gone.txt": "",
                    ]),
                    PreviewScenario.Workspace(name: "Clean", branch: "clean"),
                ]
            ),
        ]))

        let repo = try #require(try await seeder.manager.store.repos().first)
        let workspaces = try await seeder.manager.store.workspaces(repoID: repo.id)
        let review = try #require(workspaces.first { $0.branch == "review" })
        let clean = try #require(workspaces.first { $0.branch == "clean" })

        #expect(try await status(in: review.path) == [" D gone.txt", " D old.txt", " M kept.txt", "?? src/new.txt"])
        #expect(try String(contentsOfFile: review.path + "/kept.txt", encoding: .utf8) == "two\n")
        #expect(try await status(in: clean.path).isEmpty)
        #expect(try await status(in: repo.path).isEmpty)
    }

    @Test("deleting a file the worktree does not hold fails the seeding rather than passing unnoticed")
    func refusesToDeleteWhatIsNotThere() async throws {
        let seeder = try makeSeeder()
        await #expect(throws: (any Error).self) {
            try await seeder.seed(PreviewScenario(projects: [
                PreviewScenario.Project(name: "ledger", workspaces: [
                    PreviewScenario.Workspace(name: "Review", branch: "review", changes: ["missing.txt": nil]),
                ]),
            ]))
        }
    }
}
