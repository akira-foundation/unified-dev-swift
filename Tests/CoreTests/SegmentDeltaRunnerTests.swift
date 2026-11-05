import Testing
import Foundation
@testable import Core

@Suite("Segment delta through a runner", .scratchDirectory)
struct SegmentDeltaRunnerTests: HandoffTurnRunnerFixture {
    @Test("rewinding the turn a Codex runner carried the delta in makes the next prompt carry it again")
    func rewindAfterARunnerCarriedTheDelta() async throws {
        let store = try makeTestStore("delta-runner")
        let session = try await enteredFromAnotherAgent(store, agent: .codex, model: "gpt-5")
        let delivery = try await claimed(store, session, "PROMPT")
        let box = codexBox()
        let runner = try await codexRunner(store, session, box)
        defer { runner.terminateNow() }
        try await runner.sendDelivery(delivery)
        let promptSeq = try #require(try await store.delivery(id: delivery.id)?.deliveredSeq)
        emitCodexReply(box)
        await waitUntil("the first reply to confirm", within: .seconds(2)) {
            ((try? await store.activeSegment(sessionID: session.id))??.cursorSeq ?? -1) > promptSeq
        }

        let checkpoint = TurnCheckpoint(sessionID: session.id, startSeq: promptSeq, before: GitSnapshot(sessionID: session.id))
        _ = try await store.prepareTranscriptRewind(checkpoint)
        var journal = CheckpointRewind(checkpoint: checkpoint, recovery: nil, restoringFiles: false)
        journal.stage = .providerReverted
        try await store.saveCheckpointRewind(journal)
        _ = try await store.completeTranscriptRewind(sessionID: session.id)

        let delta = try await store.handoffTurn(
            "next", sessionID: session.id, deliveredSeq: nil, worktree: nil, contextWindow: nil
        )
        #expect(delta.contains("earlier words"))
    }
}
