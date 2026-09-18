import Foundation
import Testing
@testable import Core

@Suite("Agent turns")
struct AgentTurnsTests {
    private let workspace = WorkspaceID("w1")
    private let other = WorkspaceID("w2")

    private func stored(
        _ session: String,
        _ state: SessionState,
        in workspaceID: WorkspaceID? = nil
    ) -> SessionActivity {
        SessionActivity(
            sessionID: SessionID(session),
            workspaceID: workspaceID ?? workspace,
            state: state
        )
    }

    private func live(
        _ session: String,
        running: Bool = false,
        waiting: Bool = false,
        in workspaceID: WorkspaceID? = nil
    ) -> AgentTurns.Live {
        AgentTurns.Live(
            sessionID: SessionID(session),
            workspaceID: workspaceID ?? workspace,
            isRunning: running,
            isAwaitingPermission: waiting
        )
    }

    @Test("a running chat with no live transcript still reports its workspace")
    func storedRowAloneCounts() {
        let running = AgentTurns.workspaces(
            .running, stored: [stored("s1", .running)], live: []
        )
        #expect(running == [workspace])
    }

    @Test("a live turn counts before its row has been written")
    func liveTurnAloneCounts() {
        let running = AgentTurns.workspaces(
            .running, stored: [], live: [live("s1", running: true)]
        )
        #expect(running == [workspace])
    }

    @Test("a live transcript overrules its own stale row")
    func liveOverrulesStaleRow() {
        let running = AgentTurns.workspaces(
            .running, stored: [stored("s1", .running)], live: [live("s1", running: false)]
        )
        #expect(running.isEmpty)
    }

    @Test("a live transcript overrules an idle row")
    func liveOverrulesIdleRow() {
        let running = AgentTurns.workspaces(
            .running, stored: [stored("s1", .idle)], live: [live("s1", running: true)]
        )
        #expect(running == [workspace])
    }

    @Test("a live answer settles its own session and no other")
    func liveAnswerDoesNotSettleSiblings() {
        let running = AgentTurns.workspaces(
            .running,
            stored: [stored("s1", .running), stored("s2", .running)],
            live: [live("s1", running: false)]
        )
        #expect(running == [workspace])
    }

    @Test("a workspace with nothing going on is not reported")
    func quietWorkspace() {
        let running = AgentTurns.workspaces(
            .running,
            stored: [stored("s1", .idle), stored("s2", .waiting)],
            live: [live("s3", running: false)]
        )
        #expect(running.isEmpty)
    }

    @Test("a turn is in progress while any kind of turn says so, and only then")
    func midTurnAsksEveryKind() {
        #expect(!AgentTurns.isMidTurn { _ in false })
        for kind in AgentTurns.Kind.allCases {
            #expect(AgentTurns.isMidTurn { $0 == kind }, "\(kind)")
        }
    }

    @Test("the two kinds of turn are exactly the stored states that count as mid turn")
    func theKindsAreTheMidTurnStates() {
        let kinds = Set(AgentTurns.Kind.allCases.map(\.sessionState))
        for state in SessionState.allCases {
            #expect(state.isMidTurn == kinds.contains(state), "\(state)")
        }
    }

    @Test("waiting and running are separate answers")
    func waitingIsNotRunning() {
        let stored = [stored("s1", .waiting)]
        #expect(AgentTurns.workspaces(.running, stored: stored, live: []).isEmpty)
        #expect(AgentTurns.workspaces(.awaitingPermission, stored: stored, live: []) == [workspace])
    }

    @Test("a live transcript answers both questions for its session")
    func liveAnswersBoth() {
        let live = [live("s1", running: false, waiting: true)]
        #expect(AgentTurns.workspaces(.running, stored: [stored("s1", .running)], live: live).isEmpty)
        #expect(
            AgentTurns.workspaces(.awaitingPermission, stored: [stored("s1", .running)], live: live)
                == [workspace]
        )
    }

    @Test("each workspace is answered from its own sessions")
    func workspacesAreSeparate() {
        let running = AgentTurns.workspaces(
            .running,
            stored: [stored("s1", .running), stored("s2", .idle, in: other)],
            live: [live("s2", running: false, in: other)]
        )
        #expect(running == [workspace])
    }

    @Test("two workspaces working at once are both reported")
    func bothReported() {
        let running = AgentTurns.workspaces(
            .running,
            stored: [stored("s1", .running)],
            live: [live("s2", running: true, in: other)]
        )
        #expect(running == [workspace, other])
    }

    @Test("a workspace is working while any of its chats is")
    func workspaceCountsAnySession() {
        let sessions = [
            Session(id: SessionID("s1"), workspaceID: workspace),
            Session(id: SessionID("s2"), workspaceID: workspace),
        ]
        var running = sessions[1]
        running.apply(.turnStarted)

        #expect(!AgentTurns.workspace(.running, sessions: sessions, live: []))
        #expect(AgentTurns.workspace(.running, sessions: [sessions[0], running], live: []))
        #expect(
            AgentTurns.workspace(.running, sessions: sessions, live: [live("s1", running: true)])
        )
    }

    @Test("a workspace with no sessions read yet is not working")
    func workspaceWithNothingRead() {
        #expect(!AgentTurns.workspace(.running, sessions: [], live: []))
        #expect(!AgentTurns.workspace(.awaitingPermission, sessions: [], live: []))
    }

    @Test("every turn kind names the stored state it means")
    func turnStates() {
        #expect(AgentTurns.Kind.running.sessionState == .running)
        #expect(AgentTurns.Kind.awaitingPermission.sessionState == .waiting)
        #expect(AgentTurns.Kind.allCases.count == 2)
    }

    @Test("two chats running in one workspace are two agents")
    func countsSessionsNotWorkspaces() {
        let sessions = AgentTurns.sessions(
            .running,
            stored: [stored("s1", .running), stored("s2", .running), stored("s3", .idle, in: other)],
            live: []
        )
        #expect(sessions == [SessionID("s1"), SessionID("s2")])
    }

    @Test("a live turn outranks the stored row of the same chat when counting agents")
    func liveOutranksStoredForSessions() {
        let sessions = AgentTurns.sessions(
            .running,
            stored: [stored("s1", .running)],
            live: [live("s1", running: false), live("s2", running: true, in: other)]
        )
        #expect(sessions == [SessionID("s2")])
    }
}

@Suite("Session activity rows", .tags(.persistence), .scratchDirectory)
struct SessionActivityRowTests {
    private func seed(_ store: Store, name: String) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: name, path: TestScratch.unique("repo-" + name)))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: "feature/" + name,
            path: TestScratch.unique("worktree-" + name), baseBranch: "main"
        ))
    }

    @Test("only chats that are mid turn or blocked come back")
    func onlyBusyChats() async throws {
        let store = try makeTestStore("activity")
        let workspace = try await seed(store, name: "alpha")

        var running = Session(workspaceID: workspace.id)
        running.apply(.turnStarted)
        var waiting = Session(workspaceID: workspace.id)
        waiting.apply(.turnStarted)
        waiting.apply(.blocked)
        let idle = Session(workspaceID: workspace.id)

        for session in [running, waiting, idle] { _ = try await store.upsert(session) }

        let rows = try await store.sessionActivity()
        #expect(Set(rows.map(\.sessionID)) == [running.id, waiting.id])
        #expect(rows.allSatisfy { $0.workspaceID == workspace.id })
        #expect(rows.first { $0.sessionID == waiting.id }?.state == .waiting)
    }

    @Test("a closed chat and an archived workspace are left out")
    func closedAndArchivedAreLeftOut() async throws {
        let store = try makeTestStore("activity-archived")

        let live = try await seed(store, name: "live")
        var closed = Session(workspaceID: live.id)
        closed.apply(.turnStarted)
        closed = try await store.upsert(closed)
        _ = try await store.update(sessionID: closed.id) { $0.archivedAt = Date() }

        var gone = try await seed(store, name: "gone")
        var stillRunning = Session(workspaceID: gone.id)
        stillRunning.apply(.turnStarted)
        _ = try await store.upsert(stillRunning)
        gone.archive()
        _ = try await store.upsert(gone)

        #expect(try await store.sessionActivity().isEmpty)
    }
}
