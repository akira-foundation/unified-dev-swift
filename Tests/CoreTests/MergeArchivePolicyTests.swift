import Testing
import Foundation
@testable import Core

@Suite("When a merged pull request archives its workspace")
struct MergeArchivePolicyTests {
    private func pullRequest(_ number: Int, _ state: String) -> PullRequest {
        PullRequest(
            number: number,
            title: "Archive on merge",
            url: "https://github.com/akira-foundation/unified-dev-swift/pull/\(number)",
            state: state,
            branch: "feat/337-archive-on-merge",
            closedAt: state == "OPEN" ? nil : Date()
        )
    }

    @Test("a pull request seen open and now merged archives, or waits for the turn")
    func archivesTheMergeItSaw() {
        let merged = pullRequest(11, "MERGED")
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: 11, pullRequest: merged, isAgentMidTurn: false
        ) == .archiveNow)
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: 11, pullRequest: merged, isAgentMidTurn: true
        ) == .archiveAfterTurn)
    }

    @Test("with the setting off a merge is forgotten, so turning it on later archives nothing old")
    func forgetsWhenOff() {
        #expect(MergeArchivePolicy.decide(
            isEnabled: false, seenOpen: 11, pullRequest: pullRequest(11, "MERGED"), isAgentMidTurn: false
        ) == .forget)
        #expect(MergeArchivePolicy.decide(
            isEnabled: false, seenOpen: 11, pullRequest: pullRequest(11, "OPEN"), isAgentMidTurn: false
        ) == .leave)
    }

    @Test("a merge never seen open is left alone")
    func leavesAMergeNeverSeenOpen() {
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: nil, pullRequest: pullRequest(11, "MERGED"), isAgentMidTurn: false
        ) == .leave)
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: 11, pullRequest: pullRequest(10, "MERGED"), isAgentMidTurn: false
        ) == .leave)
    }

    @Test("an open or a closed pull request is left alone")
    func leavesWhatDidNotMerge() {
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: 11, pullRequest: pullRequest(11, "OPEN"), isAgentMidTurn: false
        ) == .leave)
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: 11, pullRequest: pullRequest(11, "CLOSED"), isAgentMidTurn: false
        ) == .leave)
    }

    @Test("an open pull request is written down once, and a merged one never")
    func recordsWhatIsOpen() {
        #expect(MergeArchivePolicy.seenOpenToRecord(pullRequest(11, "OPEN"), recorded: 10) == .some(11))
        #expect(MergeArchivePolicy.seenOpenToRecord(pullRequest(11, "OPEN"), recorded: nil) == .some(11))
        #expect(MergeArchivePolicy.seenOpenToRecord(pullRequest(11, "OPEN"), recorded: 11) == nil)
        #expect(MergeArchivePolicy.seenOpenToRecord(pullRequest(11, "MERGED"), recorded: 10) == nil)
        #expect(MergeArchivePolicy.seenOpenToRecord(pullRequest(11, "CLOSED"), recorded: 10) == nil)
        #expect(MergeArchivePolicy.seenOpenToRecord(pullRequest(0, "OPEN"), recorded: nil) == nil)
    }

    @Test("a wait archives once the last turn ends, and a turn stopped by hand drops it")
    func waitsForTheLastTurn() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        let unknown = waits.settle(id, isAgentMidTurn: false, wasStopped: false)
        #expect(unknown == .notWaiting)

        waits.wait(for: id)
        let otherChatStillRunning = waits.settle(id, isAgentMidTurn: true, wasStopped: false)
        #expect(otherChatStillRunning == .keepWaiting)
        let lastTurnEnded = waits.settle(id, isAgentMidTurn: false, wasStopped: false)
        #expect(lastTurnEnded == .archive)
        let again = waits.settle(id, isAgentMidTurn: false, wasStopped: false)
        #expect(again == .notWaiting)

        waits.wait(for: id)
        let stopped = waits.settle(id, isAgentMidTurn: false, wasStopped: true)
        #expect(stopped == .dropStopped)
        #expect(waits.ids.isEmpty)
    }

    @Test("a forgotten workspace has no wait left to settle")
    func forgettingDropsTheWait() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.wait(for: id)
        waits.forget(id)
        let settled = waits.settle(id, isAgentMidTurn: false, wasStopped: false)
        #expect(settled == .notWaiting)
    }
}
