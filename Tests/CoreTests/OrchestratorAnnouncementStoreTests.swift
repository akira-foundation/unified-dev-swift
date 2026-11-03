import Foundation
import Testing
@testable import Core

@Suite("Telling the orchestrator about a new workspace", .tags(.persistence), .scratchDirectory)
struct OrchestratorAnnouncementStoreTests {
    private struct Scene {
        let fixture: WorkspaceSayFixture
        let lead: Workspace
        let leadChat: Session
        var store: Store { fixture.store }
    }

    private func scene(_ label: String) async throws -> Scene {
        let f = try await WorkspaceSayFixture.make(label)
        let lead = try #require(try await f.store.setOrchestrator(true, workspaceID: f.releaser.id))
        return Scene(fixture: f, lead: lead, leadChat: f.releaserChat)
    }

    private func newWorkspace(
        in scene: Scene, origin: WorkspaceOrigin = .user
    ) async throws -> (Workspace, Session) {
        let made = try await scene.store.upsert(Workspace(
            repoID: scene.lead.repoID, name: "changelog", branch: "apex/changelog",
            path: TestScratch.unique("changelog"), baseBranch: "main", origin: origin
        ))
        let chat = try await scene.store.upsert(Session(workspaceID: made.id, title: "Chat"))
        return (made, chat)
    }

    @Test("a workspace the owner starts reaches the orchestrator's chat and is watched")
    func announcesAndWatches() async throws {
        let s = try await scene("announce")
        let (started, chat) = try await newWorkspace(in: s)

        let told = try await s.store.announceToOrchestrator(started, prompt: "Write it.", firstChat: chat)

        #expect(told?.id == s.leadChat.id)
        let delivery = try #require(try await s.store.pendingDeliveries(sessionID: s.leadChat.id).first)
        #expect(delivery.kind == .report)
        #expect(delivery.sourceWorkspaceID == started.id)
        #expect(delivery.crewMessage?.event == .workspaceStarted)
        let watches = try await s.store.unspentWorkspaceDoneWatches(targetWorkspaceID: started.id)
        #expect(watches.count == 1)
        #expect(watches.first?.cause == .start)
        #expect(watches.first?.watcherSessionID == s.leadChat.id)
        #expect(watches.first?.target.sessionID == chat.id)
    }

    @Test("an orchestrator with no live chat is not told and nothing is watched")
    func noChatNoAnnouncement() async throws {
        let s = try await scene("announce-no-chat")
        var archived = s.leadChat
        archived.archivedAt = Date()
        _ = try await s.store.upsert(archived)
        let (started, chat) = try await newWorkspace(in: s)

        let told = try await s.store.announceToOrchestrator(started, prompt: "Write it.", firstChat: chat)

        #expect(told == nil)
        #expect(try await s.store.pendingDeliveries(sessionID: s.leadChat.id).isEmpty)
        #expect(try await s.store.unspentWorkspaceDoneWatches(targetWorkspaceID: started.id).isEmpty)
    }

    @Test("the agent that started it and the orchestrator each watch it once")
    func creatorAndOrchestratorEachWatchOnce() async throws {
        let s = try await scene("announce-both")
        let origin = WorkspaceOrigin.agent(parentWorkspaceID: s.fixture.fixer.id, spawnToolUseID: "t")
        let (started, chat) = try await newWorkspace(in: s, origin: origin)
        try await s.store.watchFirstTurn(
            of: StartedWorkspaceSummary(
                workspaceID: started.id, name: started.name, branch: started.branch, path: started.path
            ),
            for: s.fixture.fixerChat.id
        )

        _ = try await s.store.announceToOrchestrator(started, prompt: "Write it.", firstChat: chat)

        let watchers = try await s.store.unspentWorkspaceDoneWatches(targetWorkspaceID: started.id)
            .map(\.watcherSessionID)
        #expect(watchers.count == 2)
        #expect(Set(watchers) == [s.fixture.fixerChat.id, s.leadChat.id])
    }

    @Test("a workspace the orchestrator starts adds nothing here")
    func orchestratorsOwnStartAddsNothing() async throws {
        let s = try await scene("announce-own")
        let origin = WorkspaceOrigin.agent(parentWorkspaceID: s.lead.id, spawnToolUseID: "t")
        let (started, chat) = try await newWorkspace(in: s, origin: origin)

        let told = try await s.store.announceToOrchestrator(started, prompt: "Write it.", firstChat: chat)

        #expect(told == nil)
        #expect(try await s.store.pendingDeliveries(sessionID: s.leadChat.id).isEmpty)
        #expect(try await s.store.unspentWorkspaceDoneWatches(targetWorkspaceID: started.id).isEmpty)
    }

    @Test("the notice names the workspace whose agent started it")
    func parentNameReachesTheNotice() async throws {
        let s = try await scene("announce-parent")
        let origin = WorkspaceOrigin.agent(parentWorkspaceID: s.fixture.fixer.id, spawnToolUseID: "t")
        let (started, chat) = try await newWorkspace(in: s, origin: origin)

        _ = try await s.store.announceToOrchestrator(started, prompt: "Write it.", firstChat: chat)

        let delivery = try #require(try await s.store.pendingDeliveries(sessionID: s.leadChat.id).first)
        #expect(delivery.sent.contains("the agent in the workspace \"fix-the-bug\""))
    }

    @Test("the first turn coming to rest reaches the orchestrator once")
    func doneNoticeArrivesOnce() async throws {
        let s = try await scene("announce-done")
        let (started, chat) = try await newWorkspace(in: s)
        _ = try await s.store.announceToOrchestrator(started, prompt: "Write it.", firstChat: chat)

        let first = try await s.store.settleWorkspaceDoneWatches(
            on: started.id, ending: .finished(lastMessage: "ok"), in: chat.id, isSubagentChat: false
        )
        let second = try await s.store.settleWorkspaceDoneWatches(
            on: started.id, ending: .finished(lastMessage: "again"), in: chat.id, isSubagentChat: false
        )

        #expect(first.map(\.id) == [s.leadChat.id])
        #expect(second.isEmpty)
    }
    @Test("a workspace with no chat is announced but not watched")
    func chatlessWorkspaceIsNotWatched() async throws {
        let s = try await scene("announce-chatless")
        let started = try await s.store.upsert(Workspace(
            repoID: s.lead.repoID, name: "shell", branch: "apex/shell",
            path: TestScratch.unique("shell"), baseBranch: "main"
        ))

        let told = try await s.store.announceToOrchestrator(started, prompt: "", firstChat: nil)

        #expect(told?.id == s.leadChat.id)
        let delivery = try #require(try await s.store.pendingDeliveries(sessionID: s.leadChat.id).first)
        #expect(!delivery.sent.contains("comes to rest"))
        #expect(try await s.store.unspentWorkspaceDoneWatches(targetWorkspaceID: started.id).isEmpty)
    }
    @Test("a workspace with a chat but no task is announced but not watched")
    func tasklessWorkspaceIsNotWatched() async throws {
        let s = try await scene("announce-taskless")
        let (started, chat) = try await newWorkspace(in: s)

        _ = try await s.store.announceToOrchestrator(started, prompt: "  \n", firstChat: chat)

        let delivery = try #require(try await s.store.pendingDeliveries(sessionID: s.leadChat.id).first)
        #expect(!delivery.sent.contains("comes to rest"))
        #expect(try await s.store.unspentWorkspaceDoneWatches(targetWorkspaceID: started.id).isEmpty)
    }

    @Test("only a top-level chat of the orchestrator is told, never a subagent's")
    func subagentChatIsNotTold() async throws {
        let s = try await scene("announce-subagent")
        var subagent = Session(workspaceID: s.lead.id, parentSessionID: s.leadChat.id, title: "Helper")
        subagent.sortOrder = -1
        _ = try await s.store.upsert(subagent)
        let (started, chat) = try await newWorkspace(in: s)

        let told = try await s.store.announceToOrchestrator(started, prompt: "Write it.", firstChat: chat)

        #expect(told?.id == s.leadChat.id)
    }
}
