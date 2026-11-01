import Foundation
import Testing
@testable import Core

@Suite("Starting a workspace in a project with an orchestrator", .tags(.git), .scratchDirectory)
struct OrchestratorAnnouncementStartTests {
    @Test("a workspace the owner starts is announced to the orchestrator's chat", .tags(.destructive))
    func startAnnouncesToTheOrchestrator() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-announce-start")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let lead = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Lead the work", origin: .user, orchestrates: true
        ))
        let leadChat = try #require(lead.session)

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Write the changelog", origin: .user
        ))

        #expect(started.announcedTo?.id == leadChat.id)
        let delivery = try #require(try await store.pendingDeliveries(sessionID: leadChat.id).first)
        #expect(delivery.sourceWorkspaceID == started.workspace.id)
        #expect(delivery.sent.contains("Write the changelog"))
    }

    @Test("starting the orchestrator itself announces nothing", .tags(.destructive))
    func orchestratorStartAnnouncesNothing() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-announce-self")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)

        let lead = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Lead the work", origin: .user, orchestrates: true
        ))

        #expect(lead.announcedTo == nil)
    }

    @Test("the orchestrator is told it hears of every workspace, whoever starts it")
    func instructionsSayEveryWorkspace() {
        #expect(OrchestratorRole.instructions.contains("whoever starts it"))
    }
    @Test("a start that asks not to announce leaves the orchestrator alone", .tags(.destructive))
    func quietStartAnnouncesNothing() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let store = try makeTestStore("orchestrator-announce-quiet")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let lead = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Lead the work", origin: .user, orchestrates: true
        ))
        let leadChat = try #require(lead.session)

        let started = try await manager.start(WorkspaceStartRequest(
            repo: registered, prompt: "Seeded", origin: .user, announcesToOrchestrator: false
        ))

        #expect(started.announcedTo == nil)
        #expect(try await store.pendingDeliveries(sessionID: leadChat.id).isEmpty)
    }
}
