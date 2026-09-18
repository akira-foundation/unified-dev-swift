import Foundation
import Testing
@testable import Core

@Suite("Workspace drafts in the store", .tags(.persistence), .scratchDirectory)
struct WorkspaceDraftStoreTests {
    private func project(_ store: Store, _ name: String) async throws -> Repo {
        try await store.upsert(Repo(name: name, path: "/tmp/\(name)"))
    }

    private func draft(in repo: Repo, prompt: String = "Tidy the pier") -> WorkspaceDraft {
        WorkspaceDraft(
            repoID: repo.id,
            startingPoint: .newBranch(from: "main"),
            prompt: prompt,
            controls: WorkspaceDraftControls(ComposerControls(model: "opus"), usesCLIChat: false),
            attachmentKey: "k1"
        )
    }

    @Test("a draft round-trips with its starting point, text, controls and attachment key")
    func roundTrips() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        let written = draft(in: harbour)
        try await store.insert(written)

        let read = try await store.workspaceDraft(repoID: harbour.id)
        #expect(read?.startingPoint == .newBranch(from: "main"))
        #expect(read?.prompt == "Tidy the pier")
        #expect(read?.controls?.model == "opus")
        #expect(read?.attachmentKey == "k1")
    }

    @Test("an existing branch and a pull request come back as they were chosen")
    func startingPointsRoundTrip() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        let quay = try await project(store, "quay")
        let request = PullRequestListing(number: 13, title: "Paint the boats", author: "kid",
                                         headRefName: "paint", baseRefName: "main")
        var onBranch = draft(in: harbour)
        onBranch.startingPoint = .existingBranch(ExistingBranch(name: "bell", isLocal: true))
        var onRequest = draft(in: quay)
        onRequest.startingPoint = .pullRequest(request)
        try await store.insert(onBranch)
        try await store.insert(onRequest)

        #expect(try await store.workspaceDraft(repoID: harbour.id)?.startingPoint
            == .existingBranch(ExistingBranch(name: "bell", isLocal: true)))
        #expect(try await store.workspaceDraft(repoID: quay.id)?.startingPoint == .pullRequest(request))
    }

    @Test("a project holds one draft, and a second insert for it is refused")
    func onePerProject() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        let quay = try await project(store, "quay")
        try await store.insert(draft(in: harbour))
        try await store.insert(draft(in: quay))

        await #expect(throws: (any Error).self) {
            try await store.insert(draft(in: harbour, prompt: "Another"))
        }
        #expect(try await store.workspaceDrafts().count == 2)
        #expect(try await store.workspaceDraft(repoID: harbour.id)?.prompt == "Tidy the pier")
    }

    @Test("a draft survives closing and reopening the database")
    func survivesReopening() async throws {
        let path = TestScratch.unique("drafts-reopen") + ".sqlite"
        let first = try Store(path: path)
        let harbour = try await project(first, "harbour")
        try await first.insert(draft(in: harbour))

        let second = try Store(path: path)
        #expect(try await second.workspaceDraft(repoID: harbour.id)?.prompt == "Tidy the pier")
    }

    @Test("an update writes what it changes and keeps the rest")
    func updateKeepsTheRest() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        try await store.insert(draft(in: harbour))

        let changed = try await store.update(workspaceDraftFor: harbour.id) { $0.prompt = "Ring the bell" }
        let read = try await store.workspaceDraft(repoID: harbour.id)
        #expect(changed?.prompt == "Ring the bell")
        #expect(read?.prompt == "Ring the bell")
        #expect(read?.startingPoint == .newBranch(from: "main"))
        #expect(read?.attachmentKey == "k1")
    }

    @Test("an update to a draft that is not there changes nothing and says so")
    func updateOfNothing() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        let changed = try await store.update(workspaceDraftFor: harbour.id) { $0.prompt = "x" }
        #expect(changed == nil)
        #expect(try await store.workspaceDrafts().isEmpty)
    }

    @Test("a draft moves to another project and leaves none behind")
    func moves() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        let quay = try await project(store, "quay")
        try await store.insert(draft(in: harbour))

        let moved = try await store.moveWorkspaceDraft(from: harbour.id, to: quay.id)
        #expect(moved?.repoID == quay.id)
        #expect(try await store.workspaceDraft(repoID: harbour.id) == nil)
        #expect(try await store.workspaceDraft(repoID: quay.id)?.prompt == "Tidy the pier")
    }

    @Test("deleting a draft leaves the other projects' drafts alone")
    func deletes() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        let quay = try await project(store, "quay")
        try await store.insert(draft(in: harbour))
        try await store.insert(draft(in: quay))

        try await store.deleteWorkspaceDraft(repoID: harbour.id)
        #expect(try await store.workspaceDrafts().map(\.repoID) == [quay.id])
    }

    @Test("removing a project takes its draft with it")
    func goesWithTheProject() async throws {
        let store = try makeTestStore("drafts")
        let harbour = try await project(store, "harbour")
        try await store.insert(draft(in: harbour))

        try await store.deleteRepo(id: harbour.id)
        #expect(try await store.workspaceDrafts().isEmpty)
    }
}

@Suite("Workspace draft rules")
struct WorkspaceDraftRuleTests {
    @Test("only a draft with something written in it counts as content")
    func contentIsText() {
        var draft = WorkspaceDraft(repoID: RepoID("r"), startingPoint: .newBranch(from: "main"))
        #expect(!draft.hasContent)
        draft.prompt = "  \n\t "
        #expect(!draft.hasContent)
        draft.prompt = "Fix it"
        #expect(draft.hasContent)
    }

    @Test("a typed pull request is not a starting point until it is looked up")
    func typedRequestIsNotStored() {
        let typed = WorkspaceSource.pullRequest(.typed(PullRequestReference(number: 13), text: "#13"))
        #expect(WorkspaceStartingPoint(typed) == nil)
        #expect(WorkspaceStartingPoint(.newBranch(from: "main")) == .newBranch(from: "main"))
    }

    @Test("a new branch has a base and no checkout, an existing branch has a checkout and no base")
    func baseAndCheckout() {
        let branch = ExistingBranch(name: "bell", isLocal: true)
        #expect(WorkspaceStartingPoint.newBranch(from: "main").baseBranch == "main")
        #expect(WorkspaceStartingPoint.newBranch(from: "main").checkout == nil)
        #expect(WorkspaceStartingPoint.existingBranch(branch).baseBranch == nil)
        #expect(WorkspaceStartingPoint.existingBranch(branch).checkout == .branch(branch))
    }

    @Test("the controls the draft keeps are the ones it gives back")
    func controlsRoundTrip() {
        let chosen = ComposerControls(model: "gpt-5", effort: "high", agentKind: .codex)
        let kept = WorkspaceDraftControls(chosen, usesCLIChat: true)
        let back = kept.applied(to: ComposerControls())
        #expect(back.model == "gpt-5")
        #expect(back.effort == "high")
        #expect(back.agentKind == .codex)
        #expect(kept.usesCLIChat)
    }

    @Test("text is inserted when there is none, updated while there is, deleted when it goes")
    func writes() {
        #expect(WorkspaceDraftWrite.decide(hasContent: true, isStored: false) == .insert)
        #expect(WorkspaceDraftWrite.decide(hasContent: true, isStored: true) == .update)
        #expect(WorkspaceDraftWrite.decide(hasContent: false, isStored: true) == .delete)
        #expect(WorkspaceDraftWrite.decide(hasContent: false, isStored: false) == .nothing)
    }
}
