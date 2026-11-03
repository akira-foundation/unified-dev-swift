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

    @Test("a command running in a terminal holds the archive back, and an agent turn outranks it")
    func waitsForACommand() {
        let merged = pullRequest(11, "MERGED")
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: 11, pullRequest: merged, isAgentMidTurn: false, isCommandRunning: true
        ) == .waitForCommand)
        #expect(MergeArchivePolicy.decide(
            isEnabled: true, seenOpen: 11, pullRequest: merged, isAgentMidTurn: true, isCommandRunning: true
        ) == .archiveAfterTurn)
        #expect(MergeArchivePolicy.decide(
            isEnabled: false, seenOpen: 11, pullRequest: merged, isAgentMidTurn: false, isCommandRunning: true
        ) == .forget)
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
        let unknown = waits.settle(id, isAgentMidTurn: false, isCommandRunning: false, wasStopped: false)
        #expect(unknown == .notWaiting)

        waits.wait(for: id, pullRequest: 11)
        let otherChatStillRunning = waits.settle(id, isAgentMidTurn: true, isCommandRunning: false, wasStopped: false)
        #expect(otherChatStillRunning == .keepWaiting)
        let lastTurnEnded = waits.settle(id, isAgentMidTurn: false, isCommandRunning: false, wasStopped: false)
        #expect(lastTurnEnded == .archive(pullRequest: 11))
        let again = waits.settle(id, isAgentMidTurn: false, isCommandRunning: false, wasStopped: false)
        #expect(again == .notWaiting)
    }

    @Test("a turn stopped by hand drops the wait even while another chat still runs")
    func stoppingDropsTheWait() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.wait(for: id, pullRequest: 11)
        let stopped = waits.settle(id, isAgentMidTurn: true, isCommandRunning: false, wasStopped: true)
        #expect(stopped == .dropStopped)
        #expect(waits.ids.isEmpty)
    }

    @Test("a forgotten workspace has no wait left to settle")
    func forgettingDropsTheWait() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.wait(for: id, pullRequest: 11)
        waits.forget(id)
        let settled = waits.settle(id, isAgentMidTurn: false, isCommandRunning: false, wasStopped: false)
        #expect(settled == .notWaiting)
    }

    @Test("a decision to wait for a command holds a wait, like one to wait for a turn", arguments: [
        MergeArchiveDecision.waitForCommand, .archiveAfterTurn
    ])
    func waitingDecisionsHoldAWait(decision: MergeArchiveDecision) {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()

        waits.record(decision, for: id, pullRequest: 11)

        #expect(waits.pullRequests == [id: 11])
    }

    @Test("a decision that ends the matter drops the wait, and leaving it does not", arguments: [
        (MergeArchiveDecision.archiveNow, true), (.forget, true), (.leave, false)
    ])
    func settledDecisionsDropTheWait(decision: MergeArchiveDecision, drops: Bool) {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.wait(for: id, pullRequest: 11)

        waits.record(decision, for: id, pullRequest: 11)

        #expect(waits.ids.isEmpty == drops)
    }

    @Test("a command still running keeps the wait, and its end archives")
    func aRunningCommandKeepsTheWait() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.record(.waitForCommand, for: id, pullRequest: 11)

        let running = waits.settle(id, isAgentMidTurn: false, isCommandRunning: true, wasStopped: false)
        #expect(running == .keepWaiting)
        #expect(waits.ids == [id])

        let ended = waits.settle(id, isAgentMidTurn: false, isCommandRunning: false, wasStopped: false)
        #expect(ended == .archive(pullRequest: 11))
        #expect(waits.ids.isEmpty)
    }

    @Test("a turn that ends with a command still running does not lose the wait")
    func aTurnEndingOverACommandKeepsTheWait() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.record(.archiveAfterTurn, for: id, pullRequest: 11)

        let settled = waits.settle(id, isAgentMidTurn: false, isCommandRunning: true, wasStopped: false)

        #expect(settled == .keepWaiting)
        #expect(waits.ids == [id])
    }

    @Test("only the first read of a running command asks to tell the owner")
    func announcesACommandWaitOnce() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()

        let first = waits.record(.waitForCommand, for: id, pullRequest: 11)
        let second = waits.record(.waitForCommand, for: id, pullRequest: 11)
        let turn = waits.record(.archiveAfterTurn, for: WorkspaceID("lisbon"), pullRequest: 12)

        #expect(first)
        #expect(second == false)
        #expect(turn == false)
    }

    @Test("a turn's wait that a command took over is still announced when a read decides so")
    func aWaitTakenOverByACommandIsAnnounced() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.record(.archiveAfterTurn, for: id, pullRequest: 11)
        _ = waits.settle(id, isAgentMidTurn: false, isCommandRunning: true, wasStopped: false)

        let announced = waits.record(.waitForCommand, for: id, pullRequest: 11)

        #expect(announced)
    }

    @Test("a settled wait for a command can be announced again")
    func aSettledCommandWaitAnnouncesAgain() {
        let id = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.record(.waitForCommand, for: id, pullRequest: 11)
        _ = waits.settle(id, isAgentMidTurn: false, isCommandRunning: false, wasStopped: false)

        let again = waits.record(.waitForCommand, for: id, pullRequest: 12)

        #expect(again)
    }

    @Test("only a wait held by a command is rechecked, so a turn's wait hears how the turn ended")
    func onlyCommandWaitsAreRechecked() {
        let turn = WorkspaceID("lisbon")
        let command = WorkspaceID("valencia")
        var waits = MergeArchiveWaits()
        waits.record(.archiveAfterTurn, for: turn, pullRequest: 11)
        waits.record(.waitForCommand, for: command, pullRequest: 12)
        #expect(waits.recheckedIDs == [command])

        _ = waits.settle(turn, isAgentMidTurn: false, isCommandRunning: true, wasStopped: false)
        #expect(waits.recheckedIDs == [turn, command])

        waits.forget(command)
        _ = waits.settle(turn, isAgentMidTurn: false, isCommandRunning: false, wasStopped: false)
        #expect(waits.recheckedIDs.isEmpty)
    }
}
