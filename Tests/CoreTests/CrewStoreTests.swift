import Foundation
import Testing
@testable import Core

@Suite("The store's half of a crew", .tags(.persistence), .scratchDirectory)
struct CrewStoreTests {
    private func makeWorkspace(
        _ store: Store, _ label: String, repo: Repo
    ) async throws -> Workspace {
        try await store.upsert(Workspace(
            repoID: repo.id,
            name: label,
            branch: "unifieddev/\(label)",
            path: TestScratch.unique("worktree-\(label)"),
            baseBranch: "main"
        ))
    }

    @discardableResult
    private func makeMember(
        _ store: Store,
        _ name: String,
        in workspace: Workspace,
        of parent: Session,
        state: SessionState = .idle
    ) async throws -> Session {
        try await store.upsert(Session(
            workspaceID: workspace.id,
            parentSessionID: parent.id,
            title: name,
            state: state
        ))
    }

    @Test("every crew member in the app comes back in one read, grouped by worktree")
    func crewGroupsByWorkspace() async throws {
        let store = try makeTestStore("crew-grouped")
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let one = try await makeWorkspace(store, "one", repo: repo)
        let two = try await makeWorkspace(store, "two", repo: repo)

        let chatOne = try await store.upsert(Session(workspaceID: one.id, title: "Chat"))
        let chatTwo = try await store.upsert(Session(workspaceID: two.id, title: "Chat"))
        try await store.upsert(Session(workspaceID: one.id, title: "Second chat"))
        try await store.upsert(Session(workspaceID: nil, title: "Ask Unified Dev"))

        try await makeMember(store, "tests", in: one, of: chatOne)
        try await makeMember(store, "docs", in: one, of: chatOne)
        try await makeMember(store, "cascade", in: two, of: chatTwo)
        let archived = try await makeMember(store, "gone", in: two, of: chatTwo)
        try await store.update(sessionID: archived.id) { $0.archivedAt = Date() }

        let grouped = try await store.crewByWorkspace()

        #expect(Set(grouped.keys) == [one.id, two.id])
        #expect(grouped[one.id].map { Set($0.map(\.title)) } == ["tests", "docs"])
        #expect(grouped[two.id].map { Set($0.map(\.title)) } == ["cascade"])
        for workspace in [one, two] {
            let perWorkspace = try await store.crew(inWorkspace: workspace.id)
            #expect(grouped[workspace.id].map { Set($0.map(\.id)) } == Set(perWorkspace.map(\.id)))
        }
    }

    @Test("an app with no crew reads back as nothing at all")
    func crewIsEmptyWithoutMembers() async throws {
        let store = try makeTestStore("crew-grouped-empty")
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let workspace = try await makeWorkspace(store, "solo", repo: repo)
        try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))

        #expect(try await store.crewByWorkspace().isEmpty)
    }

    @Test("a crew member lost to a relaunch is reported to the chat that started it")
    func relaunchReportsLostCrew() async throws {
        let store = try makeTestStore("crew-relaunch")
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let workspace = try await makeWorkspace(store, "crew", repo: repo)
        let orchestrator = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))

        let working = try await makeMember(
            store, "tests", in: workspace, of: orchestrator, state: .running
        )
        let blocked = try await makeMember(
            store, "docs", in: workspace, of: orchestrator, state: .waiting
        )
        try await makeMember(store, "quiet", in: workspace, of: orchestrator, state: .idle)

        try await store.resetRunningSessions()

        let pending = try await store.pendingDeliveries(sessionID: orchestrator.id)
        #expect(pending.count == 2)
        #expect(pending.allSatisfy { $0.kind == .report })
        #expect(pending.allSatisfy { $0.sourceWorkspaceID == workspace.id })
        #expect(pending.allSatisfy { $0.sent.contains("restarted") })
        #expect(pending.contains { $0.sent.contains("\"tests\"") })
        #expect(pending.contains { $0.sent.contains("\"docs\"") })
        #expect(pending.allSatisfy { !$0.sent.contains("\"quiet\"") })
        #expect(pending.allSatisfy { $0.crewMessage?.event == .failed })
        #expect(pending.contains { $0.body == "tests failed. Unified Dev was restarted while it was "
            + "working, so its turn was lost. Nothing it had not already reported got through." })

        #expect(try await store.session(id: working.id)?.state == .idle)
        #expect(try await store.session(id: blocked.id)?.state == .idle)
    }

    @Test("an archived orchestrator is told nothing")
    func archivedOrchestratorIsNotTold() async throws {
        let store = try makeTestStore("crew-relaunch-archived")
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let workspace = try await makeWorkspace(store, "crew", repo: repo)
        let orchestrator = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        let member = try await makeMember(
            store, "tests", in: workspace, of: orchestrator, state: .running
        )
        try await store.update(sessionID: orchestrator.id) { $0.archivedAt = Date() }

        try await store.resetRunningSessions()

        #expect(try await store.pendingDeliveries(sessionID: orchestrator.id).isEmpty)
        #expect(try await store.session(id: member.id)?.state == .idle)
    }

    @Test("an ordinary chat left running produces no delivery")
    func ordinaryChatProducesNothing() async throws {
        let store = try makeTestStore("crew-relaunch-plain")
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let workspace = try await makeWorkspace(store, "plain", repo: repo)
        let chat = try await store.upsert(Session(
            workspaceID: workspace.id, title: "Chat", state: .running
        ))

        try await store.resetRunningSessions()

        #expect(try await store.pendingDeliveries(sessionID: chat.id).isEmpty)
        #expect(try await store.session(id: chat.id)?.state == .idle)
    }
}
