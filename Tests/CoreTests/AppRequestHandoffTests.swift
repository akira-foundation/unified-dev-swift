import Foundation
import Testing
@testable import Core

@Suite("A request the app sends, when the chat changes agent", .tags(.persistence), .scratchDirectory)
struct AppRequestHandoffTests {
    private let chat = SessionID("chat")
    private let words = "the words only the app wrote"
    private let codex = SessionSegmentTarget(agentKind: .codex, accountID: nil, model: "gpt-5", effort: "high")

    private func request(_ seq: Int) throws -> Message {
        Message(sessionID: chat, seq: seq, kind: .crew, payload: try CrewMessage.appRequest(words).payload())
    }

    private func owner(_ seq: Int, _ text: String) -> Message {
        let json = JSONValue.object(["type": .string("user"), "message": .object(["content": .string(text)])])
        return Message(sessionID: chat, seq: seq, kind: .user, payload: Data(json.compactJSON.utf8))
    }

    private func reply(_ seq: Int, _ text: String) -> Message {
        let line = #"{"type":"assistant","message":{"model":"claude-test","content":[{"type":"text","text":"\#(text)"}]}}"#
        return Message(sessionID: chat, seq: seq, kind: .assistantText, payload: Data(line.utf8))
    }

    private func clean(_ seq: Int) -> Message {
        Message(sessionID: chat, seq: seq, kind: .result, payload: Data(#"{"subtype":"success","is_error":false}"#.utf8))
    }

    private func limit(_ seq: Int) throws -> Message {
        Message(
            sessionID: chat, seq: seq, kind: .assistantText,
            payload: Data(try fixtureLines("claude-usage-limit.ndjson")[0].utf8)
        )
    }

    private func delta(_ rows: [Message]) -> String {
        ConversationHandoff.text(messages: rows, worktree: nil, chatID: chat, budget: 128_000, agent: .claudeCode) ?? ""
    }

    private func makeSession(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    private func claimRequest(for session: Session, in store: Store) async throws -> Int {
        let delivery = AppRequest.delivery(to: session.id, text: words, interactionMode: nil)
        _ = try await store.enqueueDelivery(delivery)
        #expect(try await store.claimDelivery(id: delivery.id))
        return try #require(try await store.messages(sessionID: session.id).last).seq
    }

    @Test("the delta gives the reply and says who sent the request, without its words or an owner line")
    func theRequestIsNobodysMessage() throws {
        let text = delta([try request(4), reply(5, "the answer"), clean(6)])

        #expect(!text.contains(words))
        #expect(!text.contains("Owner:"))
        #expect(!text.contains("Unified Dev (unifieddev):"))
        #expect(text.contains("Assistant: the answer"))
        #expect(text.contains("Unified Dev sent the request that opened this turn, not the owner (row 4)."))
    }

    @Test("the same words pasted by the owner are the owner's message in full")
    func aPastedCopyStaysTheOwners() {
        let text = delta([owner(1, words), reply(2, "the answer"), clean(3)])

        #expect(text.contains("Owner: " + words))
        #expect(!text.contains("Unified Dev sent the request"))
    }

    @Test("an earlier turn it opened still has its own number, and the owner's reply stays in the owner's turn")
    func aRequestOpensATurn() throws {
        let rows = [owner(1, "mine"), reply(2, "my answer"), clean(3), try request(4), reply(5, "its answer"), clean(6)]
        let context = try #require(ConversationHandoff.context(
            messages: rows, worktree: nil, chatID: chat, agent: .claudeCode
        ))

        #expect(context.turns.map(\.firstSeq) == [1, 4])
        #expect(context.ownerCount == 1)
        #expect(context.turns[0].owner == "mine")
        #expect(context.turns[1].owner == nil)
        #expect(context.turns[1].replies == ["its answer"])
    }

    @Test("a request cut off while it ran reads as interrupted and is still named")
    func anUnfinishedRequestIsNamed() throws {
        let text = delta([try request(1)])

        #expect(text.contains("The last turn was interrupted before it finished."))
        #expect(text.contains("Unified Dev sent the request that opened this turn, not the owner (row 1)."))
    }

    @Test("a limit inside a turn it opened is that turn's limit, and a request after a limit is a new turn")
    func theStopCauseReadsItsTurn() throws {
        let cut = [owner(1, "mine"), clean(2), try request(3), try limit(4)]
        let after = [owner(1, "mine"), try limit(2), try request(3)]

        #expect(TurnStopCause.ofLastTurn(messages: cut, agent: .claudeCode) == .usageLimit)
        #expect(TurnStopCause.ofLastTurn(messages: after, agent: .claudeCode) == .other)
    }

    @Test("a clean end is read from the turn it opened, not from the owner's before it")
    func aCleanEndIsReadFromItsTurn() throws {
        let running = [reply(4, "working"), try request(3), clean(2), owner(1, "mine")]
        let ended = [clean(5), reply(4, "done"), try request(3), clean(2), owner(1, "mine")]

        #expect(!ConversationHandoff.lastTurnEndedCleanly(newestFirst: running, agent: .claudeCode))
        #expect(ConversationHandoff.lastTurnEndedCleanly(newestFirst: ended, agent: .claudeCode))
    }

    @Test("the next agent reads the turn and not its words, then carries them no further")
    func theDeltaAfterASwitch() async throws {
        let store = try makeTestStore("app-request-switch")
        let session = try await makeSession(store)
        _ = try await claimRequest(for: session, in: store)
        _ = try await store.appendNext(sessionID: session.id, kind: .assistantText, payload: reply(0, "the answer").payload)

        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let sent = try await store.handoffTurn(
            "next", sessionID: session.id, deliveredSeq: nil, worktree: nil, contextWindow: nil
        )

        #expect(!sent.contains(words))
        #expect(sent.contains("the answer"))
        #expect(sent.hasSuffix("next"))
    }

    @Test("a request that is the first thing the new agent gets carries the delta in front of its own words")
    func aRequestCanCarryTheDelta() async throws {
        let store = try makeTestStore("app-request-carrier")
        let session = try await makeSession(store)
        _ = try await store.appendNext(sessionID: session.id, kind: .user, payload: owner(0, "the owner asked").payload)
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let seq = try await claimRequest(for: session, in: store)

        let sent = try await store.handoffTurn(
            words, sessionID: session.id, deliveredSeq: seq, worktree: nil, contextWindow: nil
        )

        #expect(sent.contains("Owner: the owner asked"))
        #expect(sent.hasSuffix(words))
        #expect(!sent.contains("Unified Dev sent the request"))
    }

    @Test("a chat whose only turn it opened can be resumed, and the resume does not send it twice")
    func aRequestCutByTheLimitIsResumed() async throws {
        let store = try makeTestStore("app-request-resume")
        let session = try await makeSession(store)
        let seq = try await claimRequest(for: session, in: store)
        _ = try await store.appendNext(sessionID: session.id, kind: .assistantText, payload: try limit(0).payload)

        let reading = try await store.lastTurnReading(sessionID: session.id, agent: .claudeCode, newestSeq: seq + 1)
        let decision = InterruptedTurnResume.decide(InterruptedTurnResume.Facts(
            cause: reading.cause, hasOwnerTurn: reading.hasOwnerTurn, outcome: .init(written: true, queueSettled: true),
            stopsAtStart: 0, stopsNow: 0, queue: []
        ))

        #expect(reading.cause == .usageLimit)
        #expect(reading.hasOwnerTurn)
        #expect(decision == .queue(InterruptedTurnResume.instruction))
        #expect(InterruptedTurnResume.delivery(for: session.id).crewPayload == nil)
    }

    private func resumeDecision(queue: [Delivery]) -> InterruptedTurnResume.Decision {
        InterruptedTurnResume.decide(InterruptedTurnResume.Facts(
            cause: .usageLimit, hasOwnerTurn: true, outcome: .init(written: true, queueSettled: true),
            stopsAtStart: 0, stopsNow: 0, queue: queue
        ))
    }

    @Test("a request waiting holds the resume back, and the owner is not told of a message he cannot see")
    func aWaitingRequestIsNotCalledAMessage() {
        let hidden = AppRequest.delivery(to: chat, text: words, interactionMode: nil)
        let mine = Delivery(targetSessionID: chat, body: "mine")

        #expect(resumeDecision(queue: [hidden]) == .tell(InterruptedTurnResume.notResumedWhileARequestWaits))
        #expect(resumeDecision(queue: [hidden, mine]) == .tell(InterruptedTurnResume.notResumedWhileAMessageWaits))
        #expect(resumeDecision(queue: [mine]) == .tell(InterruptedTurnResume.notResumedWhileAMessageWaits))
    }

    @Test("the resume is a mark and a request is a turn, and neither is taken for the other")
    func theTwoHiddenDeliveriesStayApart() throws {
        let resume = InterruptedTurnResume.delivery(for: chat)
        let hidden = AppRequest.delivery(to: chat, text: words, interactionMode: nil)

        #expect(!AppRequest.isHidden(resume))
        #expect(!InterruptedTurnResume.isResume(hidden))
        #expect(SendingSlot.drawing(of: resume) == nil)
        #expect(SendingSlot.drawing(of: hidden) == nil)
        #expect(MessageKind.crew.opensTurn)
        #expect(!MessageKind.handoff.opensTurn)
        #expect(TurnStopCause.ofLastTurn(
            messages: [owner(1, "mine"), try limit(2), Message(sessionID: chat, seq: 3, kind: .handoff, payload: HandoffMark.resuming.payload)],
            agent: .claudeCode
        ) == .other)
    }

    @Test("neither a request nor a resume can be edited or come back as the owner's words")
    func neitherReturnsToTheComposer() {
        let hidden = AppRequest.delivery(to: chat, text: words, interactionMode: .plan)
        let resume = InterruptedTurnResume.delivery(for: chat)
        let mine = Delivery(targetSessionID: chat, body: "mine")

        for delivery in [hidden, resume] {
            #expect(!PendingMessageEdit.canEdit(delivery))
            #expect(!PendingMessageReturn.canReturn(delivery))
            #expect(PendingMessageDiscard.recovery(of: delivery, composerDraft: "") == .discarded(.notTheOwners))
        }
        #expect(PendingMessageEdit.canEdit(mine))
    }
}
