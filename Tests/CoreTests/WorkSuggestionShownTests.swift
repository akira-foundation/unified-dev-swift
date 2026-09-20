import Foundation
import Testing
@testable import Core

@Suite("A suggestion brings a hidden project back", .tags(.persistence), .scratchDirectory)
struct WorkSuggestionShownTests {
    @Test("a hidden project is shown again, and the store says so")
    func hiddenComesBack() async throws {
        let store = try makeTestStore("shown-hidden")
        let almanac = try await store.upsert(Repo(name: "almanac", path: "/tmp/almanac", hidden: true))

        let shown = try await WorkSuggestionLaunch.shown(almanac, store: store)
        let read = try await store.repo(id: almanac.id)

        #expect(!shown.hidden)
        #expect(read?.hidden == false)
    }

    @Test("a project already in the sidebar is handed back as it was")
    func visibleUntouched() async throws {
        let store = try makeTestStore("shown-visible")
        let lantern = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern"))

        let shown = try await WorkSuggestionLaunch.shown(lantern, store: store)
        let read = try await store.repo(id: lantern.id)

        #expect(shown == lantern)
        #expect(read?.hidden == false)
    }

    @Test("work in this project brings the suggesting workspace's hidden project back when it starts")
    func sameProjectComesBack() async throws {
        let f = try await WorkSuggestionLaunchFixture.make("shown-same-project")
        _ = try await f.store.update(repoID: f.repo.id) { $0.hidden = true }
        let s = try await f.suggest(target: .sameProject)
        let seams = WorkSuggestionLaunchSeams(store: f.store)

        let outcome = await seams.launch().launch(s.id, as: .newWorkspace, store: f.store)
        let read = try await f.store.repo(id: f.repo.id)

        #expect(outcome.startedSuggestion != nil, "\(outcome)")
        #expect(read?.hidden == false)
        #expect(seams.projects.map(\.hidden) == [false])
    }
}
