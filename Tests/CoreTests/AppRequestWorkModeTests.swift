import Foundation
import Testing
@testable import Core

@Suite("A queued request, when a switch settles the work mode", .tags(.persistence), .scratchDirectory)
struct AppRequestWorkModeTests {
    private let chat = SessionID("chat")

    private func source(_ agent: AgentKind, interaction: InteractionMode = .build, permission: PermissionMode = .auto) -> Session {
        var session = Session(workspaceID: WorkspaceID("w"), model: "m", agentKind: agent)
        session.permissionMode = permission
        session.interactionMode = interaction
        return session
    }

    private func request(_ mode: InteractionMode) -> Delivery {
        AppRequest.delivery(to: chat, text: "the report", interactionMode: mode)
    }

    private func decide(
        _ session: Session, onto agent: AgentKind, queue: [Delivery], route: AgentSwitchWorkMode.PlanRoute
    ) -> AgentSwitchWorkMode {
        var controls = ComposerControls(session: session, isFastMode: false, outputStyle: "")
        controls.agentKind = agent
        return AgentSwitchWorkMode.decide(from: session, to: controls, queue: queue, route: route)
    }

    @Test(
        "whatever the route and the modes, it is never handed to the composer",
        arguments: [AgentSwitchWorkMode.PlanRoute.perTurn, .perChat, .none], [InteractionMode.plan, .build]
    )
    func neverReturned(route: AgentSwitchWorkMode.PlanRoute, wanted: InteractionMode) {
        let queue = [request(wanted)]
        for interaction in [InteractionMode.plan, .build] {
            for permission in [PermissionMode.plan, .auto] {
                let session = source(.claudeCode, interaction: interaction, permission: permission)
                let decided = decide(session, onto: .codex, queue: queue, route: route)

                #expect(decided.returned.isEmpty)
                #expect(decided.returning(from: queue).isEmpty)
            }
        }
    }

    @Test("settling the queue keeps it waiting, hidden, under its new mode")
    func settlingKeepsItQueued() async throws {
        let store = try makeTestStore("app-request-settle")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id))
        let queued = AppRequest.delivery(to: session.id, text: "the report", interactionMode: .plan)
        _ = try await store.enqueueDelivery(queued)
        let decided = decide(session, onto: .codex, queue: [queued], route: .perTurn)

        let taken = try await store.settleQueue(rewriting: decided.rewritten, taking: decided.returning(from: [queued]))
        let left = try await store.pendingDeliveries(sessionID: session.id)

        #expect(taken.isEmpty)
        #expect(left.map(\.id) == [queued.id])
        #expect(left.first.map(AppRequest.isHidden) == true)
        #expect(left.first?.interactionMode == .plan)
        #expect(try await store.draft(sessionID: session.id).isEmpty)
    }

    @Test("a Plan chat stays in Plan when the first thing queued is a request sent in Build")
    func itDoesNotTakeAChatOutOfPlan() {
        let decided = decide(source(.codex, interaction: .plan), onto: .codex, queue: [request(.build)], route: .perTurn)

        #expect(decided.interactionMode == .plan)
        #expect(decided.notice == nil)
    }

    @Test("a Build chat stays in Build when the first thing queued is a request sent in Plan, which keeps its Plan")
    func itDoesNotPutAChatInPlan() {
        let queued = request(.plan)
        let decided = decide(source(.claudeCode), onto: .codex, queue: [queued], route: .perTurn)

        #expect(decided.interactionMode == .build)
        #expect(decided.rewritten[queued.id] == .plan)
        #expect(decided.notice == nil)
    }

    @Test("the owner's own message behind a request still decides the chat's mode")
    func theOwnersMessageDecides() {
        let mine = Delivery(targetSessionID: chat, kind: .owner, body: "mine", interactionMode: .plan)
        let decided = decide(source(.claudeCode), onto: .codex, queue: [request(.build), mine], route: .perTurn)

        #expect(decided.interactionMode == .plan)
    }

    @Test("on a per-chat agent a request sent in Plan never runs in Build")
    func itNeverRunsInBuildWithAPlanIntent() {
        let decided = decide(source(.codex), onto: .claudeCode, queue: [request(.plan)], route: .perChat)

        #expect(decided.permissionMode == .plan)
        #expect(decided.returned.isEmpty)
    }

    @Test("where the agent has no Plan the request is refused by the agent, and the owner is not told about attachments")
    func itIsNotDescribedAsTheOwnersAttachment() {
        let queued = request(.plan)
        let decided = decide(source(.claudeCode), onto: .codex, queue: [queued], route: .none)

        #expect(decided.rewritten[queued.id] == .plan)
        #expect(decided.notice?.contains("attachments") != true)
        #expect(decided.noticeTone == .information)
    }
}
