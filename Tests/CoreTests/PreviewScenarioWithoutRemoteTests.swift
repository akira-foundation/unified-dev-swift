import Testing
import Foundation
@testable import Core

@Suite("A preview project with no remote", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioWithoutRemoteTests {
    private let scenario = PreviewScenario(welcome: false, projects: [
        PreviewScenario.Project(
            name: "cove",
            files: ["src/rope.txt": "hemp\n"],
            commits: ["Coil the rope", "Tar the rope"],
            branches: ["spare"],
            workspaces: [
                PreviewScenario.Workspace(
                    name: "Rope",
                    branch: "rope",
                    changes: ["src/rope.txt": "sisal\n"],
                    commits: ["Splice the rope", "Whip the ends"]
                ),
            ],
            remote: .absent
        ),
    ])

    private func makeSeeder() throws -> (PreviewScenarioSeeder, String) {
        let root = TestScratch.unique("preview-no-remote")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-no-remote"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        return (PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root)), root)
    }

    private func git(_ arguments: [String], in path: String) async throws -> String {
        try await Shell.check("git", arguments, cwd: path).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("the project is seeded with its history and no remote at all")
    func seedsWithoutRemote() async throws {
        let (seeder, _) = try makeSeeder()
        let outcome = try await seeder.seed(scenario)
        #expect(outcome.projects == 1)

        let repo = try #require(try await seeder.manager.store.repos().first { $0.name == "cove" })
        let remotes = try await git(["remote"], in: repo.path)
        let commits = try await git(["rev-list", "--count", "HEAD"], in: repo.path)

        #expect(remotes.isEmpty)
        #expect(commits == "2")
        #expect(!FileManager.default.fileExists(atPath: seeder.remotesRoot + "/cove.git"))
        #expect(FileManager.default.fileExists(atPath: repo.path + "/src/rope.txt"))
    }

    @Test("a branch of its own is cut locally, because there is nowhere to push it")
    func branchesStayLocal() async throws {
        let (seeder, _) = try makeSeeder()
        _ = try await seeder.seed(scenario)

        let repo = try #require(try await seeder.manager.store.repos().first { $0.name == "cove" })
        let branches = try await git(["branch", "--format=%(refname:short)"], in: repo.path)
        let remoteBranches = try await git(["branch", "-r"], in: repo.path)

        #expect(branches.split(separator: "\n").map(String.init).sorted() == ["main", "rope", "spare"])
        #expect(remoteBranches.isEmpty)
    }

    @Test("a workspace of its own still starts, on a worktree of the branch it names")
    func workspaceStarts() async throws {
        let (seeder, root) = try makeSeeder()
        _ = try await seeder.seed(scenario)

        let store = seeder.manager.store
        let repo = try #require(try await store.repos().first { $0.name == "cove" })
        let workspace = try #require(try await store.workspaces(repoID: repo.id).first)
        let remotes = try await git(["remote"], in: workspace.path)

        #expect(workspace.branch == "rope")
        #expect(FolderPath.isInside(workspace.path, of: root + "/workspaces"))
        #expect(remotes.isEmpty)
    }

    @Test("a workspace's own commits sit ahead of the base branch, with its changes left uncommitted")
    func commitsAheadOfBase() async throws {
        let (seeder, _) = try makeSeeder()
        _ = try await seeder.seed(scenario)

        let store = seeder.manager.store
        let repo = try #require(try await store.repos().first { $0.name == "cove" })
        let workspace = try #require(try await store.workspaces(repoID: repo.id).first)
        let ahead = try await git(["rev-list", "--count", "main..HEAD"], in: workspace.path)
        let uncommitted = try await git(["status", "--porcelain"], in: workspace.path)

        #expect(ahead == "2")
        #expect(uncommitted.contains("src/rope.txt"))
    }

    @Test("a scenario cannot put a remote ahead of a project that has none")
    func cannotBeAheadOfNothing() {
        let asked = PreviewScenario(projects: [
            PreviewScenario.Project(
                name: "cove", remoteAhead: ["Ring the bell"], remote: .absent
            ),
        ])

        #expect(asked.problems == ["project \"cove\" has no remote, so nothing can be ahead of one"])
    }

    @Test("a project that keeps its remote is not refused for being ahead")
    func aheadIsFineWithARemote() {
        let asked = PreviewScenario(projects: [
            PreviewScenario.Project(name: "cove", remoteAhead: ["Ring the bell"]),
        ])

        #expect(asked.problems.isEmpty)
    }
}
