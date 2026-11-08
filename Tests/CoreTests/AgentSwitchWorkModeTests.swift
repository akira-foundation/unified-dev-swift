import Testing
import Foundation
@testable import Core

@Suite("What a switch does to the work mode", .scratchDirectory)
struct AgentSwitchWorkModeTests {
    private let chat = SessionID("chat")

    private func source(
        _ agent: AgentKind, permission: PermissionMode = .auto, interaction: InteractionMode = .build
    ) -> Session {
        var session = Session(workspaceID: WorkspaceID("w"), model: "m", agentKind: agent)
        session.permissionMode = permission
        session.interactionMode = interaction
        return session
    }

    private func picked(_ session: Session, onto agent: AgentKind) -> ComposerControls {
        var controls = ComposerControls(session: session, isFastMode: false, outputStyle: "")
        controls.agentKind = agent
        return controls
    }

    private func delivery(_ mode: InteractionMode?, kind: Delivery.Kind = .owner) -> Delivery {
        Delivery(targetSessionID: chat, kind: kind, body: "text", interactionMode: mode)
    }

    private func withAttachment(_ mode: InteractionMode) -> Delivery {
        Delivery(
            targetSessionID: chat, kind: .owner,
            body: AttachmentTrailer.compose(text: "look", paths: ["/tmp/shot.png"]), interactionMode: mode
        )
    }

    private func decide(
        _ session: Session, onto agent: AgentKind, queue: [Delivery] = [], route: AgentSwitchWorkMode.PlanRoute? = nil
    ) -> AgentSwitchWorkMode {
        AgentSwitchWorkMode.decide(
            from: session, to: picked(session, onto: agent), queue: queue,
            route: route ?? .of(agent, codexPlanningIsAvailable: true)
        )
    }

    @Test("each provider's plan route is where its runner reads it")
    func routes() {
        #expect(AgentSwitchWorkMode.PlanRoute.of(.codex, codexPlanningIsAvailable: true) == .perTurn)
        #expect(AgentSwitchWorkMode.PlanRoute.of(.codex, codexPlanningIsAvailable: false) == .none)
        #expect(AgentSwitchWorkMode.PlanRoute.of(.claudeCode, codexPlanningIsAvailable: false) == .perChat)
        #expect(AgentSwitchWorkMode.PlanRoute.of(.grok, codexPlanningIsAvailable: true) == .perChat)
    }

    @Test("the route of a Codex without Plan is read from what the runner recorded")
    func routeIsRead() async throws {
        let store = try makeTestStore("work-mode-route")
        #expect(await AgentSwitchWorkMode.PlanRoute.read(.codex, from: store) == .perTurn)

        try await store.setSetting(CodexPlanningCapability.unavailableKey, "1")

        #expect(await AgentSwitchWorkMode.PlanRoute.read(.codex, from: store) == .none)
        #expect(await AgentSwitchWorkMode.PlanRoute.read(.grok, from: store) == .perChat)
    }

    @Test("Claude in plan permission moves to Codex's plan mode")
    func claudePlanToCodex() {
        let mode = decide(source(.claudeCode, permission: .plan), onto: .codex)

        #expect(mode.interactionMode == .plan)
        #expect(mode.permissionMode != .plan)
        #expect(mode.notice == nil)
    }

    @Test("Codex in plan mode moves to the plan permission on Claude and Grok", arguments: [AgentKind.claudeCode, .grok])
    func codexPlanToChatLevel(agent: AgentKind) {
        let mode = decide(source(.codex, interaction: .plan), onto: agent)

        #expect(mode.permissionMode == .plan)
        #expect(mode.interactionMode == .build)
    }

    @Test("Build stays Build")
    func buildStaysBuild() {
        let mode = decide(source(.claudeCode, permission: .acceptEdits), onto: .codex)

        #expect(mode.interactionMode == .build)
        #expect(mode.permissionMode == .acceptEdits)
    }

    @Test("a mode the owner picked in the same gesture wins over the one the chat had")
    func anExplicitChoiceWins() {
        let session = source(.claudeCode, permission: .plan)
        var controls = picked(session, onto: .codex)
        controls.permissionMode = .bypassPermissions

        let mode = AgentSwitchWorkMode.decide(from: session, to: controls, queue: [], route: .perTurn)

        #expect(mode.interactionMode == .build)
        #expect(mode.permissionMode == .bypassPermissions)
    }

    @Test("a queued message in Claude's plan permission reaches Codex in plan")
    func queuedUnderPlanPermissionToCodex() {
        let queued = delivery(.build)
        let mode = decide(source(.claudeCode, permission: .plan), onto: .codex, queue: [queued])

        #expect(mode.rewritten[queued.id] == .plan)
        #expect(mode.interactionMode == .plan)
        #expect(mode.returned.isEmpty)
    }

    @Test("the chat's mode follows the first queued message, so a turn and its chat agree")
    func theChatFollowsTheFirstMessage() {
        let queued = delivery(.plan)
        let mode = decide(source(.codex), onto: .claudeCode, queue: [queued])

        #expect(mode.permissionMode == .plan)
        #expect(mode.interactionMode == .build)
        #expect(mode.rewritten[queued.id] == .build)
    }

    @Test("Codex runs each queued message in its own mode")
    func codexHonoursEachMessage() {
        let plan = delivery(.plan)
        let build = delivery(.build)
        let mode = decide(source(.grok), onto: .codex, queue: [plan, build])

        #expect(mode.rewritten == [plan.id: .plan, build.id: .build])
        #expect(mode.interactionMode == .plan)
        #expect(mode.returned.isEmpty)
    }

    @Test("a provider with one mode per chat hands back the message that disagrees with the first")
    func oneModePerChatHandsBackTheOther() {
        let build = delivery(.build)
        let plan = delivery(.plan)
        let mode = decide(source(.codex), onto: .claudeCode, queue: [build, plan])

        #expect(mode.permissionMode != .plan)
        #expect(mode.returned == [plan.id])
        #expect(mode.rewritten[plan.id] == nil)
        #expect(mode.notice?.contains("composer") == true)
    }

    @Test("a Codex without Plan hands back a plan message rather than running it in Build")
    func aCodexWithoutPlanHandsBack() {
        let plan = delivery(.plan)
        let build = delivery(.build)
        let mode = decide(source(.claudeCode), onto: .codex, queue: [plan, build], route: AgentSwitchWorkMode.PlanRoute.none)

        #expect(mode.returned == [plan.id])
        #expect(mode.rewritten[plan.id] == nil)
        #expect(mode.rewritten[build.id] == .build)
        #expect(mode.interactionMode == .build)
        #expect(mode.notice?.contains("composer") == true)
    }

    @Test("a chat in plan moving to a Codex without Plan says it is now in Build")
    func aPlanChatOnACodexWithoutPlanSaysSo() {
        let mode = decide(source(.claudeCode, permission: .plan), onto: .codex, route: AgentSwitchWorkMode.PlanRoute.none)

        #expect(mode.interactionMode == .build)
        #expect(mode.notice?.contains("Build") == true)
    }

    @Test("a message with no mode of its own follows the chat and is never handed back")
    func aMessageWithNoModeFollowsTheChat() {
        let report = delivery(nil, kind: .report)
        let plan = delivery(.plan)
        let mode = decide(source(.codex), onto: .claudeCode, queue: [report, plan])

        #expect(mode.permissionMode == .plan)
        #expect(mode.rewritten[report.id] == nil)
        #expect(mode.returned.isEmpty)
    }

    @Test("a crew message carries no mode, so it follows the chat without moving it")
    func aCrewMessageFollowsTheChat() {
        let message = CrewMessage(event: .said, sender: .subagent, from: "worker", text: "text", sent: "text")
        let crew = Delivery(targetSessionID: chat, kind: .message, crew: message)
        let mode = decide(source(.claudeCode), onto: .codex, queue: [crew], route: AgentSwitchWorkMode.PlanRoute.none)

        #expect(crew.interactionMode == nil)
        #expect(mode.returned.isEmpty)
        #expect(mode.rewritten[crew.id] == nil)
        #expect(mode.notice == nil)
    }

    @Test("a plan message that cannot go back holds a one mode chat in plan, and the Build message goes back")
    func aStuckPlanMessageHoldsTheChatInPlan() {
        let build = delivery(.build)
        let attached = withAttachment(.plan)
        let mode = decide(source(.codex), onto: .claudeCode, queue: [build, attached])

        #expect(mode.permissionMode == .plan)
        #expect(mode.interactionMode == .build)
        #expect(mode.returned == [build.id])
        #expect(mode.rewritten[attached.id] == .build)
        #expect(mode.notice?.contains("composer") == true)
        #expect(mode.notice?.contains("now in Plan") == true)
    }

    @Test("a stuck plan message overrides a Build the owner picked in the same gesture, and says so")
    func aStuckPlanMessageOverridesAnExplicitBuild() {
        let session = source(.codex)
        var controls = picked(session, onto: .claudeCode)
        controls.permissionMode = .bypassPermissions

        let mode = AgentSwitchWorkMode.decide(from: session, to: controls, queue: [withAttachment(.plan)], route: .perChat)

        #expect(mode.permissionMode == .plan)
        #expect(mode.notice?.contains("now in Plan") == true)
    }

    @Test("a Build message that cannot go back stays queued in a chat held in plan")
    func aStuckBuildMessageStaysInAPlanChat() {
        let build = withAttachment(.build)
        let plan = withAttachment(.plan)
        let mode = decide(source(.codex), onto: .claudeCode, queue: [build, plan])

        #expect(mode.permissionMode == .plan)
        #expect(mode.returned.isEmpty)
        #expect(mode.rewritten[build.id] == nil)
    }

    @Test("a chat in plan keeps a message with an attachment on a provider with one mode per chat, without a notice")
    func aStuckPlanMessageInAPlanChatSaysNothing() {
        let attached = withAttachment(.plan)
        let mode = decide(source(.codex, interaction: .plan), onto: .claudeCode, queue: [attached])

        #expect(mode.permissionMode == .plan)
        #expect(mode.rewritten[attached.id] == .build)
        #expect(mode.notice == nil)
    }

    @Test("a plan chat on a Codex without Plan sends a stuck message in plan, so it is refused in sight")
    func aStuckMessageIsRefusedOnACodexWithoutPlan() {
        let attached = withAttachment(.build)
        let mode = decide(
            source(.claudeCode, permission: .plan), onto: .codex, queue: [attached],
            route: AgentSwitchWorkMode.PlanRoute.none
        )

        #expect(mode.interactionMode == .build)
        #expect(mode.returned.isEmpty)
        #expect(mode.rewritten[attached.id] == .plan)
        #expect(mode.notice?.contains("now in Build") == true)
        #expect(mode.notice?.contains("will refuse") == true)
        #expect(mode.noticeTone == .warning)
    }

    @Test("a Build chat warns about the stuck plan message without saying it lost Plan")
    func aStuckMessageInABuildChatWarns() {
        let attached = withAttachment(.plan)
        let mode = decide(source(.claudeCode), onto: .codex, queue: [attached], route: AgentSwitchWorkMode.PlanRoute.none)

        #expect(mode.rewritten[attached.id] == .plan)
        #expect(mode.notice?.contains("will refuse") == true)
        #expect(mode.notice?.contains("now in Build") == false)
        #expect(mode.noticeTone == .warning)
    }

    @Test("a Build message with an attachment simply runs on a Codex without Plan")
    func aStuckBuildMessageRunsOnACodexWithoutPlan() {
        let attached = withAttachment(.build)
        let mode = decide(source(.claudeCode), onto: .codex, queue: [attached], route: AgentSwitchWorkMode.PlanRoute.none)

        #expect(mode.rewritten[attached.id] == .build)
        #expect(mode.notice == nil)
    }

    @Test("Codex honours a stuck message's plan, so nothing has to be held or refused")
    func aStuckMessageIsNoProblemPerTurn() {
        let build = delivery(.build)
        let attached = withAttachment(.plan)
        let mode = decide(source(.grok), onto: .codex, queue: [build, attached])

        #expect(mode.rewritten == [build.id: .build, attached.id: .plan])
        #expect(mode.interactionMode == .build)
        #expect(mode.notice == nil)
    }

    @Test("a message whose delivery is in doubt is left alone")
    func anUncertainMessageIsLeftAlone() {
        let uncertain = Delivery(targetSessionID: chat, body: "text", state: .uncertain, interactionMode: .plan)
        let mode = decide(source(.codex), onto: .claudeCode, queue: [uncertain])

        #expect(mode.rewritten.isEmpty)
        #expect(mode.returned.isEmpty)
    }

    private func queuedChat(_ store: Store, agent: AgentKind, permission: PermissionMode = .auto) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        var row = Session(workspaceID: workspace.id, model: "m", agentKind: agent)
        row.permissionMode = permission
        return try await store.upsert(row)
    }

    @Test("settling writes the new modes and takes back what returns, and only those")
    func settling() async throws {
        let store = try makeTestStore("work-mode-settle")
        let session = try await queuedChat(store, agent: .codex)
        let build = try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "first", interactionMode: .build))
        let plan = try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "second", interactionMode: .plan))
        let queue = [build, plan]
        let mode = AgentSwitchWorkMode.decide(
            from: session, to: picked(session, onto: .claudeCode), queue: queue, route: .perChat
        )

        let returned = try await store.settleQueue(rewriting: mode.rewritten, taking: mode.returning(from: queue))

        #expect(returned.map(\.id) == [plan.id])
        let left = try await store.pendingDeliveries(sessionID: session.id)
        #expect(left.map(\.id) == [build.id])
        #expect(left.first?.interactionMode == .build)
    }

    @Test("settling rewrites a queued message's mode in the store")
    func settlingRewrites() async throws {
        let store = try makeTestStore("work-mode-rewrite")
        let session = try await queuedChat(store, agent: .claudeCode, permission: .plan)
        let queued = try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "go", interactionMode: .build))
        let mode = AgentSwitchWorkMode.decide(
            from: session, to: picked(session, onto: .codex), queue: [queued], route: .perTurn
        )

        _ = try await store.settleQueue(rewriting: mode.rewritten, taking: [])

        #expect(try await store.delivery(id: queued.id)?.interactionMode == .plan)
    }

    @Test("a failure while settling leaves the whole queue as it was")
    func aFailedSettleChangesNothing() async throws {
        let path = TestScratch.unique("work-mode-atomic") + ".sqlite"
        let store = try Store(path: path)
        let session = try await queuedChat(store, agent: .codex)
        let kept = try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "kept", interactionMode: .plan))
        let taken = try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "taken", interactionMode: .plan))
        let blocked = try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "blocked", interactionMode: .plan))
        let raw = try SQLiteDatabase(path: path)
        try raw.execute("""
            CREATE TRIGGER refuse_blocked BEFORE DELETE ON deliveries WHEN OLD.id = '\(blocked.id.rawValue)'
            BEGIN SELECT RAISE(ABORT, 'refused'); END;
            """)

        await #expect(throws: (any Error).self) {
            try await store.settleQueue(rewriting: [kept.id: .build], taking: [taken, blocked])
        }

        let left = try await store.pendingDeliveries(sessionID: session.id)
        #expect(left.map(\.id) == [kept.id, taken.id, blocked.id])
        #expect(left.first?.interactionMode == .plan)
    }

    @Test("a chat in plan stays in plan on a provider with one mode per chat, and the Build message goes back")
    func aPlanChatStaysInPlan() {
        let build = delivery(.build)
        let mode = decide(source(.codex, interaction: .plan), onto: .claudeCode, queue: [build])

        #expect(mode.permissionMode == .plan)
        #expect(mode.returned == [build.id])
        #expect(mode.notice?.contains("composer") == true)
    }

    @Test("a Build chat that goes to plan for its first message says so", arguments: [
        (AgentKind.claudeCode, AgentSwitchWorkMode.PlanRoute.perChat),
        (AgentKind.codex, AgentSwitchWorkMode.PlanRoute.perTurn),
    ])
    func aBuildChatGoingToPlanSaysSo(agent: AgentKind, route: AgentSwitchWorkMode.PlanRoute) {
        let from: AgentKind = agent == .codex ? .grok : .codex
        let mode = decide(source(from), onto: agent, queue: [delivery(.plan)], route: route)

        #expect(mode.notice?.contains("now in Plan") == true)
        #expect(mode.noticeTone == .information)
    }

    @Test("a plan chat on a Codex without Plan warns that it is now in Build, with or without a queue")
    func losingPlanWarns() {
        let empty = decide(source(.claudeCode, permission: .plan), onto: .codex, route: AgentSwitchWorkMode.PlanRoute.none)
        let queued = decide(
            source(.claudeCode, permission: .plan), onto: .codex, queue: [delivery(.build)],
            route: AgentSwitchWorkMode.PlanRoute.none
        )

        #expect(empty.notice?.contains("now in Build") == true)
        #expect(empty.noticeTone == .warning)
        #expect(queued.notice?.contains("composer") == true)
        #expect(queued.notice?.contains("now in Build") == true)
        #expect(queued.noticeTone == .warning)
    }

    @Test("a Build chat on a Codex without Plan hands back its plan message without saying it lost Plan")
    func aBuildChatLosesNothing() {
        let mode = decide(source(.claudeCode), onto: .codex, queue: [delivery(.plan)], route: AgentSwitchWorkMode.PlanRoute.none)

        #expect(mode.notice?.contains("now in Build") == false)
        #expect(mode.noticeTone == .information)
    }

    @Test("the applied controls carry the decided modes")
    func appliedControls() {
        let session = source(.claudeCode, permission: .plan)
        let controls = picked(session, onto: .codex)
        let mode = AgentSwitchWorkMode.decide(from: session, to: controls, queue: [], route: .perTurn)

        #expect(mode.applied(to: controls).interactionMode == .plan)
        #expect(mode.applied(to: controls).agentKind == .codex)
    }
}
