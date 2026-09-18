import Testing
import Foundation
@testable import Core

@Suite("Seeding a preview scenario", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioSeederTests {
    private let scenario = PreviewScenario(welcome: false, projects: [
        PreviewScenario.Project(
            name: "harbour",
            files: ["src/pier.txt": "wood\n"],
            commits: ["Lay the pier", "Paint the boats"],
            remoteAhead: ["Light the lighthouse", "Ring the bell"],
            workspaces: [
                PreviewScenario.Workspace(name: "Lighthouse", branch: "lighthouse", chats: [
                    PreviewScenario.Chat(title: "Plan", messages: [
                        PreviewScenario.Line(from: .user, text: "Is the \"lamp\" lit?"),
                        PreviewScenario.Line(from: .agent, text: "Yes."),
                    ]),
                ]),
                PreviewScenario.Workspace(name: "Bell", branch: "bell"),
            ]
        ),
    ])

    private func makeSeeder() throws -> (PreviewScenarioSeeder, String) {
        let root = TestScratch.unique("preview")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        return (PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root)), root)
    }

    private func git(_ arguments: [String], in path: String) async throws -> String {
        try await Shell.check("git", arguments, cwd: path).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("projects, workspaces and chats arrive through the store, all inside the preview root")
    func seedsEverything() async throws {
        let (seeder, root) = try makeSeeder()
        let outcome = try await seeder.seed(scenario)
        #expect(outcome == PreviewScenarioSeeder.Outcome(projects: 1, workspaces: 2, chats: 1))

        let store = seeder.manager.store
        let repo = try #require(try await store.repos().first)
        #expect(repo.path.hasSuffix("/scratch/projects/harbour"))
        #expect(FolderPath.isInside(repo.path, of: root))
        #expect(repo.defaultBranch == "main")

        let workspaces = try await store.workspaces(repoID: repo.id)
        #expect(Set(workspaces.map(\.branch)) == ["lighthouse", "bell"])
        for workspace in workspaces {
            #expect(FolderPath.isInside(workspace.path, of: root + "/workspaces"))
            #expect(FileManager.default.fileExists(atPath: workspace.path + "/src/pier.txt"))
        }

        let lighthouse = try #require(workspaces.first { $0.branch == "lighthouse" })
        let chat = try #require(try await store.sessions(workspaceID: lighthouse.id).first)
        #expect(chat.title == "Plan")
        let messages = try await store.messages(sessionID: chat.id)
        #expect(messages.map(\.kind) == [.user, .assistantText])
        #expect(String(decoding: messages[0].payload, as: UTF8.self).contains(#"Is the \"lamp\" lit?"#))

        let bell = try #require(workspaces.first { $0.branch == "bell" })
        #expect(try await store.sessions(workspaceID: bell.id).count == 1)
    }

    @Test("the remote holds commits the project has not fetched")
    func remoteIsAhead() async throws {
        let (seeder, _) = try makeSeeder()
        _ = try await seeder.seed(scenario)
        let project = seeder.projectsRoot + "/harbour"

        #expect(try await git(["rev-list", "--count", "HEAD"], in: project) == "2")
        #expect(try await git(["rev-list", "--count", "HEAD..origin/main"], in: project) == "0")
        try await Shell.check("git", ["fetch", "-q"], cwd: project)
        #expect(try await git(["rev-list", "--count", "HEAD..origin/main"], in: project) == "2")
        #expect(!FileManager.default.fileExists(atPath: seeder.remotesRoot + "/harbour.upstream"))
    }

    @Test("a preview that already holds projects is left as it is")
    func seedsOnce() async throws {
        let (seeder, _) = try makeSeeder()
        _ = try await seeder.seed(scenario)
        await #expect(throws: PreviewScenarioError.alreadySeeded) { try await seeder.seed(scenario) }
        #expect(try await seeder.manager.store.repos().count == 1)
    }

    @Test("an invalid scenario creates nothing at all")
    func invalidCreatesNothing() async throws {
        let (seeder, root) = try makeSeeder()
        let broken = PreviewScenario(projects: [PreviewScenario.Project(name: "../out")])
        await #expect(throws: PreviewScenarioError.self) { try await seeder.seed(broken) }
        #expect(!FileManager.default.fileExists(atPath: root))
    }

    @Test("a chat line is stored in the shape the transcript reads")
    func payloadShape() throws {
        let payload = try PreviewScenarioSeeder.payload("hi")
        let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        let message = object?["message"] as? [String: Any]
        let content = message?["content"] as? [[String: Any]]
        #expect(content?.first?["type"] as? String == "text")
        #expect(content?.first?["text"] as? String == "hi")
    }
}
