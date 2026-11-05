import Foundation
import Testing
@testable import Core

@Suite("A work card stays inside the profile that filed it", .tags(.git, .subprocess, .persistence), .scratchDirectory)
struct WorkSuggestionProfileTests {
    private static let slug = "octo/parsekit"

    private func suggestRemote(_ world: ProfileScopeWorld, as identity: BridgeIdentity) async throws -> WorkSuggestion {
        let answer = await WorkSuggestTool().call(
            world.request("work_suggest", [
                "title": .string("Lay it out"), "why": .string("Nothing is there yet."),
                "prompt": .string("Lay out the package."), "project": .string(Self.slug),
            ]),
            as: identity, store: world.store
        )
        #expect(!answer.isError, "\(answer.text)")
        let session = try #require(identity.sessionID)
        return try #require(try await world.store.workSuggestions(sessionID: session).first)
    }

    private func clone(_ world: ProfileScopeWorld) async throws -> Repo {
        let repo = try await TempRepo()
        try await Git.addRemote("origin", url: "https://github.com/\(Self.slug).git", in: repo.path)
        let added = await ProjectAddTool().call(
            world.request("project_add", ["path": .string(repo.path)]), as: .owner, store: world.store
        )
        #expect(!added.isError, "\(added.text)")
        let projects = try await world.store.repos()
        return try #require(projects.first { FolderPath.sameFolder($0.path, repo.path) })
    }

    @Test("a card is not adopted by a clone in another profile, and does not start there")
    func crossProfileClone() async throws {
        let world = try await ProfileScopeWorld.make("card-cross-clone")
        let suggestion = try await suggestRemote(world, as: world.homeAgent)
        try await world.store.setActiveProfile(world.akira)

        let cloned = try await clone(world)

        #expect(cloned.profileID == world.akira)
        #expect(try await world.store.workSuggestion(id: suggestion.id)?.target == .remote(Self.slug))

        let seams = WorkSuggestionLaunchSeams(store: world.store)
        let outcome = await seams.launch().launch(suggestion.id, as: .newWorkspace, store: world.store)

        #expect(outcome.startedSuggestion == nil)
        #expect(seams.projects.isEmpty)
        #expect(try await world.store.workspaces(repoID: cloned.id, includeArchived: true).isEmpty)
    }

    @Test("a card is adopted by a clone in its own workspace's profile")
    func sameProfileClone() async throws {
        let world = try await ProfileScopeWorld.make("card-same-clone")
        let suggestion = try await suggestRemote(world, as: world.farAgent)
        try await world.store.setActiveProfile(world.akira)

        let cloned = try await clone(world)

        #expect(try await world.store.workSuggestion(id: suggestion.id)?.target == .project(cloned.id))
    }

    @Test("a project moved to another profile after the card was filed refuses the start, and stays hidden")
    func movedProject() async throws {
        let world = try await ProfileScopeWorld.make("card-moved")
        let sibling = try await world.store.upsert(Repo(name: "sibling", path: TestScratch.unique("sibling")))
        let session = try #require(world.homeAgent.sessionID)
        let suggestion = try #require(try await world.store.addWorkSuggestion(WorkSuggestion(
            workspaceID: world.homeWorkspace.id, sessionID: session, title: "T", why: "W", prompt: "P",
            target: .project(sibling.id)
        )).suggestion)
        try await world.store.update(repoID: sibling.id) { $0.hidden = true }
        try await world.store.move(repoID: sibling.id, to: world.akira)

        let seams = WorkSuggestionLaunchSeams(store: world.store)
        let outcome = await seams.launch().launch(suggestion.id, as: .newWorkspace, store: world.store)

        #expect(outcome.startedSuggestion == nil)
        #expect(seams.projects.isEmpty)
        #expect(try await world.store.repo(id: sibling.id)?.hidden == true)
    }

    @Test("a folder card admitted into another profile does not start there")
    func folderElsewhere() async throws {
        let world = try await ProfileScopeWorld.make("card-folder")
        let session = try #require(world.farAgent.sessionID)
        let suggestion = try #require(try await world.store.addWorkSuggestion(WorkSuggestion(
            workspaceID: world.farWorkspace.id, sessionID: session, title: "T", why: "W", prompt: "P",
            target: .folder(world.homeProject.path)
        )).suggestion)
        let seams = WorkSuggestionLaunchSeams(store: world.store)
        seams.admission = .success(world.homeProject)

        let outcome = await seams.launch().launch(suggestion.id, as: .newWorkspace, store: world.store)

        #expect(outcome.startedSuggestion == nil)
        #expect(seams.projects.isEmpty)
    }

    @Test("a card in its own profile still starts in another project of that profile")
    func sameProfileProject() async throws {
        let world = try await ProfileScopeWorld.make("card-same-project")
        let sibling = try await world.store.upsert(Repo(name: "sibling", path: TestScratch.unique("sibling")))
        let session = try #require(world.homeAgent.sessionID)
        let suggestion = try #require(try await world.store.addWorkSuggestion(WorkSuggestion(
            workspaceID: world.homeWorkspace.id, sessionID: session, title: "T", why: "W", prompt: "P",
            target: .project(sibling.id)
        )).suggestion)
        let seams = WorkSuggestionLaunchSeams(store: world.store)

        let outcome = await seams.launch().launch(suggestion.id, as: .newWorkspace, store: world.store)

        #expect(outcome.startedSuggestion != nil)
        #expect(seams.projects.map(\.id) == [sibling.id])
    }
}

@Suite("Which project a card may reach")
struct WorkSuggestionProfileRuleTests {
    @Test("a card from a workspace reaches only that workspace's profile")
    func fromWorkspace() {
        let akira = ProfileID("akira")

        #expect(WorkSuggestionProfile.admits(project: akira, from: .workspace(akira)))
        #expect(!WorkSuggestionProfile.admits(project: .initial, from: .workspace(akira)))
    }

    @Test("a card whose workspace can no longer be read reaches nothing")
    func fromGoneWorkspace() {
        #expect(!WorkSuggestionProfile.admits(project: .initial, from: .workspace(nil)))
    }

    @Test("a card from a chat in no workspace has no profile to stay in")
    func fromNoWorkspace() {
        #expect(WorkSuggestionProfile.admits(project: ProfileID("akira"), from: .noWorkspace))
    }
}
