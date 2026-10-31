import Foundation
import Testing
@testable import Core

@Suite("A suggestion aimed at GitHub finds its project once it is cloned", .tags(.git, .subprocess, .persistence), .scratchDirectory)
struct WorkSuggestionRemoteAdoptionTests {
    @Test("an origin on GitHub reads as its slug, in every form git writes it", arguments: [
        ("git@github.com:octo/parsekit.git", "octo/parsekit"),
        ("https://github.com/octo/parsekit.git", "octo/parsekit"),
        ("https://github.com/octo/parsekit", "octo/parsekit"),
        ("ssh://git@github.com/octo/parsekit.git", "octo/parsekit"),
        ("HTTPS://GitHub.com/Octo/ParseKit/", "Octo/ParseKit"),
    ])
    func readsTheSlug(url: String, slug: String) {
        #expect(WorkSuggestionTarget.gitHubSlug(ofRemote: url) == slug)
    }

    @Test("an origin anywhere else has no slug", arguments: [
        "git@gitlab.com:octo/parsekit.git",
        "https://gitlab.com/octo/parsekit",
        "octo/parsekit",
        "/Users/kid/parsekit.git",
        "https://github.com/octo",
    ])
    func refusesOtherOrigins(url: String) {
        #expect(WorkSuggestionTarget.gitHubSlug(ofRemote: url) == nil)
    }

    private struct Fixture {
        let manager: WorkspaceManager
        let chat: Session

        var store: Store { manager.store }

        func suggest(_ slug: String) async throws -> WorkSuggestion {
            let suggestion = WorkSuggestion(
                workspaceID: nil,
                sessionID: chat.id,
                title: "Skeleton for \(slug)",
                why: "Nothing is there yet.",
                prompt: "Lay out the package.",
                target: .remote(slug)
            )
            return try #require(try await store.addWorkSuggestion(suggestion).suggestion)
        }

        func target(of suggestion: WorkSuggestion) async throws -> WorkSuggestion.Target? {
            try await store.workSuggestion(id: suggestion.id)?.target
        }
    }

    private func fixture(_ label: String) async throws -> Fixture {
        let store = try makeTestStore(label)
        let chat = try await store.upsert(Session(workspaceID: nil, title: "Owner"))
        let manager = WorkspaceManager(
            store: store,
            workspacesRoot: URL(fileURLWithPath: TestScratch.unique("workspaces"), isDirectory: true)
        )
        return Fixture(manager: manager, chat: chat)
    }

    private func clone(origin: String?) async throws -> TempRepo {
        let repo = try await TempRepo()
        if let origin { try await Git.addRemote("origin", url: origin, in: repo.path) }
        return repo
    }

    @Test("adding the clone turns a waiting suggestion for its slug into one for the project")
    func adoptsOnAdd() async throws {
        let f = try await fixture("remote-adopt")
        let waiting = try await f.suggest("octo/parsekit")
        let repo = try await clone(origin: "git@github.com:Octo/ParseKit.git")
        defer { repo.cleanUp() }

        let project = try await f.manager.addRepository(at: repo.path)
        let target = try await f.target(of: waiting)

        #expect(target == .project(project.id))
    }

    @Test("adding a project that was already there still adopts a suggestion made since")
    func adoptsOnReAdd() async throws {
        let f = try await fixture("remote-readd")
        let repo = try await clone(origin: "https://github.com/octo/parsekit.git")
        defer { repo.cleanUp() }
        let project = try await f.manager.addRepository(at: repo.path)
        let waiting = try await f.suggest("octo/parsekit")

        _ = try await f.manager.addRepository(at: repo.path)
        let target = try await f.target(of: waiting)

        #expect(target == .project(project.id))
    }

    @Test("a suggestion for another slug, or one already decided, keeps its target")
    func leavesOthersAlone() async throws {
        let f = try await fixture("remote-others")
        let other = try await f.suggest("octo/lantern")
        let dismissed = try await f.suggest("octo/parsekit")
        _ = try await f.store.dismissWorkSuggestion(id: dismissed.id)
        let repo = try await clone(origin: "git@github.com:octo/parsekit.git")
        defer { repo.cleanUp() }

        _ = try await f.manager.addRepository(at: repo.path)
        let otherTarget = try await f.target(of: other)
        let dismissedTarget = try await f.target(of: dismissed)

        #expect(otherTarget == .remote("octo/lantern"))
        #expect(dismissedTarget == .remote("octo/parsekit"))
    }

    @Test("a project with no origin, or one off GitHub, changes no suggestion", arguments: [
        nil,
        "git@gitlab.com:octo/parsekit.git",
    ] as [String?])
    func needsAGitHubOrigin(origin: String?) async throws {
        let f = try await fixture("remote-no-origin")
        let waiting = try await f.suggest("octo/parsekit")
        let repo = try await clone(origin: origin)
        defer { repo.cleanUp() }

        _ = try await f.manager.addRepository(at: repo.path)
        let target = try await f.target(of: waiting)

        #expect(target == .remote("octo/parsekit"))
    }

    @Test("once adopted, the card offers a new workspace and a draft instead of Dismiss alone")
    func cardOffersStart() async throws {
        let f = try await fixture("remote-card")
        let waiting = try await f.suggest("octo/parsekit")
        let repo = try await clone(origin: "git@github.com:octo/parsekit.git")
        defer { repo.cleanUp() }

        let project = try await f.manager.addRepository(at: repo.path)
        let adopted = try #require(try await f.store.workSuggestion(id: waiting.id))
        let context = WorkSuggestionCard.Context.of(
            adopted, workspaces: [], repos: [project], chatIsSubagent: false
        )

        #expect(WorkSuggestionCard.offers(for: adopted, in: context).map(\.action) == [.newWorkspace, .dismiss])
        #expect(WorkSuggestionCard.opensAsDraft(adopted))
    }
}
