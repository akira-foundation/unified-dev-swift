import Testing
import Foundation
@testable import Core

@Suite("Resuming a turn the usage limit cut short", .tags(.persistence), .scratchDirectory)
struct InterruptedTurnResumeTests {
    private func seed(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    private func line(_ text: String) -> String {
        #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"\#(text)"}]}}"#
    }

    private func append(_ store: Store, _ session: Session, _ kind: MessageKind, _ json: String) async throws {
        _ = try await store.appendNext(sessionID: session.id, kind: kind, payload: Data(json.utf8))
    }

    private let limit = #"{"type":"assistant","message":{"model":"<synthetic>","content":[{"type":"text","text":"You've hit your session limit"}]},"error":"rate_limit","is_api_error_message":true,"api_error_status":429}"#

    private let reply = #"{"type":"assistant","message":{"model":"claude-opus-5","role":"assistant","content":[{"type":"text","text":"working on it"}]}}"#

    private func facts(
        cause: TurnStopCause = .usageLimit,
        hasOwnerTurn: Bool = true,
        outcome: AgentSwitch.Outcome = .init(written: true, queueSettled: true),
        stopsAtStart: Int = 0,
        stopsNow: Int = 0,
        queue: [Delivery] = [],
        origin: InterruptedTurnResume.Origin = .providerSwitch
    ) -> InterruptedTurnResume.Facts {
        InterruptedTurnResume.Facts(
            origin: origin, cause: cause, hasOwnerTurn: hasOwnerTurn, outcome: outcome,
            stopsAtStart: stopsAtStart, stopsNow: stopsNow, queue: queue
        )
    }

    private func queueResume(_ store: Store, _ session: Session) async throws -> Delivery {
        try await store.enqueueDelivery(InterruptedTurnResume.delivery(for: session.id))
    }

    private func ownerDelivery(_ session: Session, _ body: String = "carry on") -> Delivery {
        Delivery(targetSessionID: session.id, body: body, interactionMode: .build)
    }

    @Test func theInstructionIsTheFixedSentence() {
        #expect(InterruptedTurnResume.instruction
            == "The previous turn was interrupted by the usage limit. Check the real state of the repository before repeating any action, then continue the task.")
    }

    @Test func onlyTheLimitResumes() {
        #expect(InterruptedTurnResume.applies(cause: .usageLimit))
        #expect(!InterruptedTurnResume.applies(cause: .other))
        #expect(InterruptedTurnResume.decide(facts()) == .queue(InterruptedTurnResume.instruction))
        #expect(InterruptedTurnResume.decide(facts(cause: .other)) == .skip)
    }

    @Test func aSignOutOrAnyOtherCauseQueuesNothingAndLeavesTheOwnerToWrite() {
        #expect(InterruptedTurnResume.decide(facts(cause: .other, queue: [])) == .skip)
    }

    @Test func aSwitchThatDidNotHappenNeverResumes() {
        let failed = AgentSwitch.Outcome(written: false, queueSettled: true)
        #expect(InterruptedTurnResume.decide(facts(outcome: failed)) == .skip)
    }

    @Test func aQueueThatDidNotSettleNeverGetsAResume() {
        let stuck = AgentSwitch.Outcome(written: true, queueSettled: false)
        #expect(InterruptedTurnResume.decide(facts(outcome: stuck)) == .skip)
    }

    @Test func aChatWithNoOwnerTurnIsMovedWithoutAResume() {
        #expect(InterruptedTurnResume.decide(facts(hasOwnerTurn: false)) == .skip)
    }

    @Test func aStopDuringTheSwitchCancelsTheResume() {
        #expect(InterruptedTurnResume.decide(facts(stopsAtStart: 2, stopsNow: 3)) == .skip)
        #expect(InterruptedTurnResume.decide(facts(stopsAtStart: 3, stopsNow: 3)) == .queue(InterruptedTurnResume.instruction))
    }

    @Test func aWaitingMessageBlocksTheResumeAndTheOwnerIsToldWhy() {
        let waiting = Delivery(targetSessionID: SessionID("c"), body: "x")
        #expect(InterruptedTurnResume.decide(facts(queue: [waiting]))
            == .tell(InterruptedTurnResume.notResumedWhileAMessageWaits))
        let already = InterruptedTurnResume.delivery(for: SessionID("c"))
        #expect(InterruptedTurnResume.decide(facts(queue: [already]))
            == .tell(InterruptedTurnResume.notResumedWhileAMessageWaits))
    }

    @Test func anUnclassifiedStopNeverResumes() async throws {
        let store = try makeTestStore("resume-unclassified")
        let session = try await seed(store)
        try await append(store, session, .user, line("go"))
        try await append(store, session, .assistantText, reply)
        try await append(store, session, .result, #"{"type":"result","subtype":"error","is_error":true,"result":"something odd"}"#)

        let reading = try await store.lastTurnReading(sessionID: session.id, agent: .claudeCode, newestSeq: 3)

        #expect(reading.cause == .other)
        #expect(InterruptedTurnResume.decide(facts(cause: reading.cause)) == .skip)
    }

    @Test func aMeasuredLimitOnClaudeIsTheOnlyCauseTheStoreClassifies() async throws {
        let store = try makeTestStore("resume-classified")
        let session = try await seed(store)
        try await append(store, session, .user, line("go"))
        try await append(store, session, .assistantText, limit)

        let claude = try await store.lastTurnReading(sessionID: session.id, agent: .claudeCode, newestSeq: 2)
        let codex = try await store.lastTurnReading(sessionID: session.id, agent: .codex, newestSeq: 2)

        #expect(claude.cause == .usageLimit)
        #expect(claude.hasOwnerTurn)
        #expect(codex.cause == .other)
    }

    @Test func anOwnerTurnOlderThanTheReadingWindowIsStillFound() async throws {
        let store = try makeTestStore("resume-old-turn")
        let session = try await seed(store)
        try await append(store, session, .user, line("go"))
        for _ in 0..<250 { try await append(store, session, .assistantText, reply) }
        try await append(store, session, .assistantText, limit)

        let reading = try await store.lastTurnReading(sessionID: session.id, agent: .claudeCode, newestSeq: 251)
        let empty = try await store.lastTurnReading(sessionID: try await seed(store).id, agent: .claudeCode, newestSeq: 0)

        #expect(reading.hasOwnerTurn)
        #expect(reading.cause == .usageLimit)
        #expect(!empty.hasOwnerTurn)
    }

    @Test func aResumeQueuedBeforeAStopMayNotRunAfterIt() {
        let waiting = [InterruptedTurnResume.delivery(for: SessionID("c"))]
        #expect(!InterruptedTurnResume.shouldDropWaiting(in: waiting, markedAt: 3, now: 3))
        #expect(InterruptedTurnResume.shouldDropWaiting(in: waiting, markedAt: 3, now: 4))
        #expect(InterruptedTurnResume.shouldDropWaiting(in: waiting, markedAt: nil, now: 0))
        #expect(!InterruptedTurnResume.shouldDropWaiting(in: [], markedAt: nil, now: 0))
    }

    @Test func aStopCountedAfterTheMarkDropsTheResumeThatWasQueued() async throws {
        let store = try makeTestStore("resume-stop-counter")
        let session = try await seed(store)
        let queued = try await queueResume(store, session)
        let queue = try await store.pendingDeliveries(sessionID: session.id)

        #expect(InterruptedTurnResume.shouldDropWaiting(in: queue, markedAt: 0, now: 1))
        let dropped = try await store.dropUnstartedResumes(sessionID: session.id)

        #expect(dropped == 1)
        #expect(try await store.delivery(id: queued.id) == nil)
    }

    enum Stage: String, CaseIterable { case pending, claimed, uncertain }

    private func reach(_ stage: Stage, _ delivery: Delivery, in store: Store) async throws {
        guard stage != .pending else { return }
        _ = try await store.claimDelivery(id: delivery.id)
        if stage == .uncertain { try await store.beginDeliveryDispatch(id: delivery.id) }
    }

    @Test(arguments: Stage.allCases)
    func aStopDropsAResumeThatNeverStartedInAnyState(_ stage: Stage) async throws {
        let store = try makeTestStore("resume-stop-\(stage.rawValue)")
        let session = try await seed(store)
        let queued = try await queueResume(store, session)
        try await reach(stage, queued, in: store)

        let dropped = try await store.dropUnstartedResumes(sessionID: session.id)

        #expect(dropped == 1)
        #expect(try await store.delivery(id: queued.id) == nil)
        #expect(try await store.pendingDeliveries(sessionID: session.id).isEmpty)
    }

    @Test(arguments: Stage.allCases)
    func aLaunchDropsAResumeThatNeverStartedInAnyState(_ stage: Stage) async throws {
        let store = try makeTestStore("resume-launch-\(stage.rawValue)")
        let session = try await seed(store)
        let written = try await store.enqueueDelivery(ownerDelivery(session))
        let queued = try await queueResume(store, session)
        try await reach(stage, queued, in: store)
        try await store.recoverDeliveryClaims()

        try await store.dropUnstartedResumes()

        #expect(try await store.delivery(id: queued.id) == nil)
        #expect(try await store.pendingDeliveries(sessionID: session.id).map(\.id) == [written.id])
    }

    @Test func anOwnerMessageDropsOnlyAResumeStillWaiting() async throws {
        let store = try makeTestStore("resume-submit-pending")
        let session = try await seed(store)
        let queued = try await queueResume(store, session)

        let dropped = try await store.dropUnstartedResumes(sessionID: session.id, onlyWaiting: true)

        #expect(dropped == 1)
        #expect(try await store.delivery(id: queued.id) == nil)
    }

    @Test(arguments: [Stage.claimed, Stage.uncertain])
    func anOwnerMessageLeavesAResumeInFlightAlone(_ stage: Stage) async throws {
        let store = try makeTestStore("resume-submit-\(stage.rawValue)")
        let session = try await seed(store)
        let queued = try await queueResume(store, session)
        try await reach(stage, queued, in: store)

        let dropped = try await store.dropUnstartedResumes(sessionID: session.id, onlyWaiting: true)

        #expect(dropped == 0)
        #expect(try await store.delivery(id: queued.id) != nil)
    }

    @Test(arguments: Stage.allCases)
    func anAbandonedResumeIsDroppedWhateverStateItReached(_ stage: Stage) async throws {
        let store = try makeTestStore("resume-abandon-\(stage.rawValue)")
        let session = try await seed(store)
        let queued = try await queueResume(store, session)
        try await reach(stage, queued, in: store)

        try await store.releaseOrDropClaim(of: queued)

        #expect(try await store.delivery(id: queued.id) == nil)
    }

    @Test func anAbandonedOwnerMessageStaysForALaterAttempt() async throws {
        let store = try makeTestStore("resume-abandon-owner")
        let session = try await seed(store)
        let written = try await store.enqueueDelivery(ownerDelivery(session))
        _ = try await store.claimDelivery(id: written.id)

        try await store.releaseOrDropClaim(of: written)

        #expect(try await store.delivery(id: written.id)?.state == .pending)
    }

    @Test func aResumeTheAgentAcceptedIsHistoryAndStaysOnEveryDrop() async throws {
        let store = try makeTestStore("resume-accepted")
        let session = try await seed(store)
        let queued = try await queueResume(store, session)
        try await reach(.uncertain, queued, in: store)
        try await store.acceptDelivery(id: queued.id)

        let dropped = try await store.dropUnstartedResumes(sessionID: session.id)
        try await store.dropUnstartedResumes()

        #expect(dropped == 0)
        #expect(try await store.delivery(id: queued.id)?.state == .accepted)
    }

    @Test func aStopDropsOnlyTheResumesOfThatChat() async throws {
        let store = try makeTestStore("resume-scope")
        let first = try await seed(store)
        let second = try await seed(store)
        _ = try await queueResume(store, first)
        let other = try await queueResume(store, second)

        try await store.dropUnstartedResumes(sessionID: first.id)

        #expect(try await store.delivery(id: other.id) != nil)
    }

    @Test func resumeDeliveryIsNotAnOwnerMessage() async throws {
        let store = try makeTestStore("resume-claim")
        let session = try await seed(store)
        try await append(store, session, .user, line("build it"))
        try await append(store, session, .assistantText, reply)
        let queued = try await queueResume(store, session)

        let claimed = try await store.claimDelivery(id: queued.id)
        let rows = try await store.messages(sessionID: session.id)
        let last = try #require(rows.last)

        #expect(claimed)
        #expect(last.kind == .handoff)
        #expect(HandoffMark.decode(last.payload) == .resuming)
        #expect(rows.filter { $0.kind == .user }.count == 1)
        let seen = rows.map { TurnAnswer.Row(seq: $0.seq, kind: $0.kind, payload: $0.payload) }
        #expect(TurnAnswer.text(summary: "", rows: seen, endingAt: last.seq + 1) == "")
    }

    @Test func theResumeRowDoesNotCountAsAnOwnerTurnInTheDelta() async throws {
        let store = try makeTestStore("resume-delta")
        let session = try await seed(store)
        try await append(store, session, .user, line("build it"))
        try await append(store, session, .assistantText, limit)
        let queued = try await queueResume(store, session)
        _ = try await store.claimDelivery(id: queued.id)
        let rows = try await store.messages(sessionID: session.id)

        let text = ConversationHandoff.text(
            messages: rows, worktree: nil, chatID: session.id, budget: 100_000, agent: .claudeCode
        )

        #expect(text?.contains("Resuming the interrupted task") == false)
        #expect(text?.contains(InterruptedTurnResume.instruction) == false)
        #expect(rows.filter { $0.kind.opensTurn }.count == 1)
    }

    @Test func aResumedLimitIsNotReadAsTheCauseAgainButANewOneIs() async throws {
        let store = try makeTestStore("resume-no-loop")
        let session = try await seed(store)
        try await append(store, session, .user, line("build it"))
        try await append(store, session, .assistantText, limit)
        let queued = try await queueResume(store, session)
        _ = try await store.claimDelivery(id: queued.id)
        try await store.beginDeliveryDispatch(id: queued.id)
        try await store.acceptDelivery(id: queued.id)

        let afterClaim = try await store.lastTurnReading(sessionID: session.id, agent: .claudeCode, newestSeq: 3)
        try await append(store, session, .assistantText, limit)
        let afterNewLimit = try await store.lastTurnReading(sessionID: session.id, agent: .claudeCode, newestSeq: 4)

        #expect(afterClaim.cause == .other)
        #expect(afterNewLimit.cause == .usageLimit)
        #expect(try await store.pendingDeliveries(sessionID: session.id).isEmpty)
    }

    @Test func aResumeIsNeverTheOwnersToTakeBack() {
        let resume = InterruptedTurnResume.delivery(for: SessionID("c"))
        #expect(!PendingMessageReturn.canReturn(resume))
        #expect(PendingMessageReturn.returning(from: [resume]).isEmpty)
        #expect(PendingMessageReturn.keeping(from: [resume]).count == 1)
        #expect(!PendingMessageEdit.canEdit(resume))
        #expect(PendingMessageDiscard.recovery(of: resume, composerDraft: "") == .discarded(.notTheOwners))
        #expect(PendingMessageDiscard.canDiscard(resume))
    }

    @Test func aResumeKeepsNoModeThatTheOwnerDidNotChoose() async throws {
        let store = try makeTestStore("resume-work-mode")
        let session = try await seed(store)
        let waiting = try await queueResume(store, session)
        let controls = ComposerControls(agentKind: .codex)

        for route in [AgentSwitchWorkMode.PlanRoute.perTurn, .perChat, .none] {
            let decided = AgentSwitchWorkMode.decide(from: session, to: controls, queue: [waiting], route: route)
            #expect(decided.rewritten.isEmpty)
            #expect(decided.returned.isEmpty)
            #expect(decided.notice == nil)
        }
        let settled = try await store.settleQueue(rewriting: [:], taking: [])
        let kept = try #require(try await store.pendingDeliveries(sessionID: session.id).first)

        #expect(settled.isEmpty)
        #expect(kept.id == waiting.id)
        #expect(kept.interactionMode == nil)
        #expect(kept.crewPayload == nil)
    }

    @Test func aResumeIsNotDrawnAsAnOwnerBubbleAndRetiresOnItsOwnDivider() {
        let resume = InterruptedTurnResume.delivery(for: SessionID("c"))
        let owner = Delivery(targetSessionID: SessionID("c"), body: "hi")

        #expect(SendingSlot.drawing(of: resume) == nil)
        #expect(SendingSlot.drawing(of: owner) == .ownerTurn)
        #expect(SendingSlot.retires(resume, onPersisting: .handoff))
        #expect(!SendingSlot.retires(owner, onPersisting: .handoff))
    }

    private func quota(_ cause: TurnStopCause = .other, hasOwnerTurn: Bool = true, queue: [Delivery] = []) -> InterruptedTurnResume.Facts {
        facts(cause: cause, hasOwnerTurn: hasOwnerTurn, queue: queue, origin: .quotaAccount)
    }

    @Test func theQuotaButtonResumesWhateverTheProviderReadsAsTheCause() {
        #expect(InterruptedTurnResume.decide(quota(.other)) == .queue(InterruptedTurnResume.didNotFinishInstruction))
        #expect(InterruptedTurnResume.decide(quota(.usageLimit)) == .queue(InterruptedTurnResume.didNotFinishInstruction))
    }

    @Test func theQuotaButtonResumesInTheMiddleOfATurn() {
        let stopped = facts(cause: .other, stopsAtStart: 1, stopsNow: 1, origin: .quotaAccount)
        #expect(InterruptedTurnResume.decide(stopped) == .queue(InterruptedTurnResume.didNotFinishInstruction))
    }

    @Test func theInstructionOfTheButtonDoesNotClaimTheLimit() {
        #expect(InterruptedTurnResume.didNotFinishInstruction
            == "The previous turn did not finish. Check the real state of the repository before repeating any action, then continue the task.")
        #expect(!InterruptedTurnResume.didNotFinishInstruction.contains("limit"))
        #expect(InterruptedTurnResume.delivery(for: SessionID("c"), instruction: InterruptedTurnResume.didNotFinishInstruction).body
            == InterruptedTurnResume.didNotFinishInstruction)
    }

    @Test func aSignOutMovesTheAccountWithoutAResume() {
        let signedOut = facts(cause: .usageLimit, origin: .accountOnly)
        #expect(InterruptedTurnResume.decide(signedOut) == .skip)
    }

    @Test func theQuotaButtonStillNeedsAnOwnerTurnAStillChatAndAFreeQueue() {
        #expect(InterruptedTurnResume.decide(quota(hasOwnerTurn: false)) == .skip)
        let stopped = facts(stopsAtStart: 1, stopsNow: 2, origin: .quotaAccount)
        #expect(InterruptedTurnResume.decide(stopped) == .skip)
        let waiting = Delivery(targetSessionID: SessionID("c"), body: "x")
        #expect(InterruptedTurnResume.decide(quota(queue: [waiting])) == .tell(InterruptedTurnResume.notResumedWhileAMessageWaits))
        let failed = facts(outcome: .init(written: false, queueSettled: true), origin: .quotaAccount)
        #expect(InterruptedTurnResume.decide(failed) == .skip)
    }

    @Test func theLimitOfClaudeKeepsItsOwnInstruction() {
        #expect(InterruptedTurnResume.decide(facts()) == .queue(InterruptedTurnResume.instruction))
    }

    @Test func anOrphanResumingMarkDoesNotBlockTheQuotaButton() async throws {
        let store = try makeTestStore("resume-orphan-mark")
        let session = try await seed(store)
        try await append(store, session, .user, line("go"))
        try await append(store, session, .assistantText, limit)
        let queued = try await queueResume(store, session)
        _ = try await store.claimDelivery(id: queued.id)
        try await store.dropUnstartedResumes(sessionID: session.id)

        let reading = try await store.lastTurnReading(sessionID: session.id, agent: .claudeCode, newestSeq: 3)

        #expect(reading.cause == .other)
        #expect(InterruptedTurnResume.decide(quota(reading.cause, hasOwnerTurn: reading.hasOwnerTurn))
            == .queue(InterruptedTurnResume.didNotFinishInstruction))
    }

    @Test func aTellJoinsTheNoticeAlreadyShownInsteadOfReplacingIt() {
        #expect(InterruptedTurnResume.told("B", after: "A") == "A B")
        #expect(InterruptedTurnResume.told("B", after: nil) == "B")
    }
}
