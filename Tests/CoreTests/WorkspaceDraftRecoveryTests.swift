import Foundation
import Testing
@testable import Core

@Suite("Drafts left behind by a quit during creation", .tags(.persistence), .scratchDirectory)
struct WorkspaceDraftRecoveryTests {
    private func project(_ store: Store, _ name: String) async throws -> Repo {
        try await store.upsert(Repo(name: name, path: "/tmp/\(name)"))
    }

    private func draft(in repo: Repo, creatingAs id: WorkspaceID? = nil) -> WorkspaceDraft {
        WorkspaceDraft(
            repoID: repo.id, startingPoint: .newBranch(from: "main"), prompt: "Tidy the pier",
            attachmentKey: "k-\(repo.name)", creatingAs: id
        )
    }

    @Test("the workspace a draft was being created as is remembered in the store")
    func creatingAsRoundTrips() async throws {
        let store = try makeTestStore("recovery")
        let harbour = try await project(store, "harbour")
        try await store.insert(draft(in: harbour, creatingAs: WorkspaceID("w1")))
        #expect(try await store.workspaceDraft(repoID: harbour.id)?.creatingAs == WorkspaceID("w1"))

        try await store.update(workspaceDraftFor: harbour.id) { $0.creatingAs = nil }
        #expect(try await store.workspaceDraft(repoID: harbour.id)?.creatingAs == nil)
    }

    @Test("a draft is finished only once its workspace exists and its prompt has arrived there")
    func fateFollowsTheWorkspaceAndThePrompt() {
        let harbour = Repo(name: "harbour", path: "/tmp/harbour")
        let marked = draft(in: harbour, creatingAs: WorkspaceID("cut"))
        let session = SessionID("chat")

        #expect(WorkspaceDraftRecovery.fate(
            of: draft(in: harbour), workspaceExists: true, promptArrived: true, firstSession: session
        ) == .keep)
        #expect(WorkspaceDraftRecovery.fate(
            of: marked, workspaceExists: false, promptArrived: false, firstSession: nil
        ) == .keep)
        #expect(WorkspaceDraftRecovery.fate(
            of: marked, workspaceExists: true, promptArrived: true, firstSession: session
        ) == .finished)
        #expect(WorkspaceDraftRecovery.fate(
            of: marked, workspaceExists: true, promptArrived: false, firstSession: session
        ) == .handOver(session))
        #expect(WorkspaceDraftRecovery.fate(
            of: marked, workspaceExists: true, promptArrived: false, firstSession: nil
        ) == .keep)
    }

    private func workspace(in repo: Repo, _ store: Store, delivered: Bool) async throws -> (Workspace, Session) {
        let created = try await store.upsert(Workspace(
            repoID: repo.id, name: "Pier", branch: "pier-\(repo.name)",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let chat = try await store.upsert(Session(workspaceID: created.id, title: "Chat"))
        if delivered {
            _ = try await store.enqueueDelivery(Delivery(targetSessionID: chat.id, body: "Tidy the pier"))
        }
        return (created, chat)
    }

    @Test("on launch a draft whose prompt reached its workspace is deleted, and one whose cut never finished keeps its prompt")
    func settlesTheStore() async throws {
        let store = try makeTestStore("recovery")
        let harbour = try await project(store, "harbour")
        let quay = try await project(store, "quay")
        let (created, _) = try await workspace(in: harbour, store, delivered: true)
        try await store.insert(draft(in: harbour, creatingAs: created.id))
        try await store.insert(draft(in: quay, creatingAs: WorkspaceID("never-cut")))

        let outcome = try await WorkspaceDraftRecovery.settle(in: store)

        #expect(outcome.finished.map(\.repoID) == [harbour.id])
        #expect(try await store.workspaceDraft(repoID: harbour.id) == nil)
        let survivor = try await store.workspaceDraft(repoID: quay.id)
        #expect(survivor?.prompt == "Tidy the pier")
        #expect(survivor?.creatingAs == nil)
        #expect(outcome.kept.map(\.repoID) == [quay.id])
    }

    @Test("a quit after the cut but before the prompt was sent moves the prompt into the workspace's chat")
    func handsThePromptToTheWorkspace() async throws {
        let store = try makeTestStore("recovery")
        let harbour = try await project(store, "harbour")
        let (created, chat) = try await workspace(in: harbour, store, delivered: false)
        try await store.insert(draft(in: harbour, creatingAs: created.id))

        let outcome = try await WorkspaceDraftRecovery.settle(in: store)

        #expect(outcome.handedOver.map(\.repoID) == [harbour.id])
        #expect(try await store.workspaceDraft(repoID: harbour.id) == nil)
        #expect(try await store.draft(sessionID: chat.id) == "Tidy the pier")
    }

    @Test("the id a draft records before the cut is the id the started workspace is stored under")
    func recordedIDMatchesTheStartedWorkspace() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let manager = WorkspaceManager(store: try makeTestStore("recovery-start"))
        let registered = try await manager.addRepository(at: repo.path)
        let id = WorkspaceID.new()
        try await manager.store.insert(draft(in: registered, creatingAs: id))

        _ = try await manager.start(WorkspaceStartRequest(
            id: id, repo: registered, prompt: "Tidy the pier", origin: .user, setupPolicy: .skip
        ))
        let outcome = try await WorkspaceDraftRecovery.settle(in: manager.store)

        #expect(outcome.handedOver.map(\.repoID) == [registered.id])
        #expect(try await manager.store.workspaceDraft(repoID: registered.id) == nil)
    }
}
