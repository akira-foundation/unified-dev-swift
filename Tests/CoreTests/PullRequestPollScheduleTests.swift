import Foundation
import Testing
@testable import Core

@Suite("PullRequestPollSchedule")
struct PullRequestPollScheduleTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func row(
        _ name: String,
        branch: String = "main",
        hasDiff: Bool = true,
        hasKnownPullRequest: Bool = false,
        isDrawn: Bool = true
    ) -> PullRequestPollSchedule.Row {
        PullRequestPollSchedule.Row(
            id: WorkspaceID(rawValue: name),
            branch: branch,
            hasDiff: hasDiff,
            hasKnownPullRequest: hasKnownPullRequest,
            isDrawn: isDrawn
        )
    }

    private func ids(_ names: String...) -> [WorkspaceID] {
        names.map { WorkspaceID(rawValue: $0) }
    }

    @Test("a row with no diff and no pull request is never asked about")
    func nothingToAsk() {
        var schedule = PullRequestPollSchedule()
        let due = schedule.due(rows: [row("clean", hasDiff: false)], now: start)
        #expect(due.isEmpty)
    }

    @Test("a known pull request is asked about without a diff")
    func knownPullRequestIsAsked() {
        var schedule = PullRequestPollSchedule()
        let due = schedule.due(rows: [row("merged", hasDiff: false, hasKnownPullRequest: true)], now: start)
        #expect(due == ids("merged"))
    }

    @Test("every drawn row is due at once, and again only after the drawn interval")
    func drawnCadence() {
        var schedule = PullRequestPollSchedule()
        let rows = [row("a"), row("b"), row("c")]
        let first = schedule.due(rows: rows, now: start)
        let tooSoon = schedule.due(
            rows: rows, now: start.addingTimeInterval(PullRequestPollSchedule.drawnInterval - 1)
        )
        let again = schedule.due(
            rows: rows, now: start.addingTimeInterval(PullRequestPollSchedule.drawnInterval)
        )
        #expect(first == ids("a", "b", "c"))
        #expect(tooSoon.isEmpty)
        #expect(again == ids("a", "b", "c"))
    }

    @Test("a drawn row never asks more often than one read per drawn interval, ticked for an hour")
    func drawnRowsNeverExceedTheOldRate() {
        var schedule = PullRequestPollSchedule()
        let rows = [row("a"), row("b")]
        var reads = 0
        var now = start
        while now < start.addingTimeInterval(3600) {
            reads += schedule.due(rows: rows, now: now).count
            now = now.addingTimeInterval(PullRequestPollSchedule.tick)
        }
        #expect(PullRequestPollSchedule.drawnInterval == 120)
        #expect(reads == 2 * 30)
    }

    @Test("rows off screen are slower than drawn rows")
    func offScreenCadence() {
        var schedule = PullRequestPollSchedule()
        let rows = [row("hidden", isDrawn: false)]
        let first = schedule.due(rows: rows, now: start)
        let afterDrawnInterval = schedule.due(
            rows: rows, now: start.addingTimeInterval(PullRequestPollSchedule.drawnInterval)
        )
        let afterOwnInterval = schedule.due(
            rows: rows, now: start.addingTimeInterval(PullRequestPollSchedule.offScreenInterval)
        )
        #expect(PullRequestPollSchedule.offScreenInterval > PullRequestPollSchedule.drawnInterval)
        #expect(first == ids("hidden"))
        #expect(afterDrawnInterval.isEmpty)
        #expect(afterOwnInterval == ids("hidden"))
    }

    @Test("rows off screen take turns, oldest first, so launch is no burst")
    func offScreenRowsTakeTurns() {
        var schedule = PullRequestPollSchedule()
        let rows = [row("a", isDrawn: false), row("b", isDrawn: false), row("c", isDrawn: false)]
        let tick = PullRequestPollSchedule.tick
        let first = schedule.due(rows: rows, now: start)
        let second = schedule.due(rows: rows, now: start.addingTimeInterval(tick))
        let third = schedule.due(rows: rows, now: start.addingTimeInterval(tick * 2))
        let fourth = schedule.due(rows: rows, now: start.addingTimeInterval(tick * 3))
        #expect(first == ids("a"))
        #expect(second == ids("b"))
        #expect(third == ids("c"))
        #expect(fourth.isEmpty)
    }

    @Test("drawn rows do not wait behind the turn of a row off screen")
    func drawnRowsAreNotCapped() {
        var schedule = PullRequestPollSchedule()
        let rows = [row("hidden", isDrawn: false), row("a"), row("hidden2", isDrawn: false), row("b")]
        let due = schedule.due(rows: rows, now: start)
        #expect(due == ids("a", "b", "hidden"))
    }

    @Test("a row coming on screen is due at once when its last read is older than the drawn interval")
    func comingOnScreenCatchesUp() {
        var schedule = PullRequestPollSchedule()
        _ = schedule.due(rows: [row("a", isDrawn: false)], now: start)
        let returned = schedule.due(
            rows: [row("a", isDrawn: true)],
            now: start.addingTimeInterval(PullRequestPollSchedule.drawnInterval)
        )
        #expect(returned == ids("a"))
    }

    @Test("a row coming back on screen inside the drawn interval reads nothing new")
    func comingOnScreenSoonAsksNothing() {
        var schedule = PullRequestPollSchedule()
        _ = schedule.due(rows: [row("a")], now: start)
        _ = schedule.due(rows: [row("a", isDrawn: false)], now: start.addingTimeInterval(10))
        let returned = schedule.due(rows: [row("a")], now: start.addingTimeInterval(20))
        #expect(returned.isEmpty)
    }

    @Test("a new branch or a new diff asks again straight away", arguments: [
        (branch: "feature", hasDiff: true),
        (branch: "main", hasDiff: false),
    ])
    func changedQuestionAsksAgain(change: (branch: String, hasDiff: Bool)) {
        var schedule = PullRequestPollSchedule()
        _ = schedule.due(rows: [row("a", hasKnownPullRequest: true)], now: start)
        let changed = row("a", branch: change.branch, hasDiff: change.hasDiff, hasKnownPullRequest: true)
        let due = schedule.due(rows: [changed], now: start.addingTimeInterval(1))
        #expect(due == ids("a"))
    }

    @Test("a row gone from the list is forgotten, so restoring it asks at once")
    func goneRowIsForgotten() {
        var schedule = PullRequestPollSchedule()
        _ = schedule.due(rows: [row("a")], now: start)
        _ = schedule.due(rows: [], now: start.addingTimeInterval(1))
        let restored = schedule.due(rows: [row("a")], now: start.addingTimeInterval(2))
        #expect(restored == ids("a"))
    }
    @Test("a row built from a workspace knows its pull request from the recorded number or from a read")
    func rowFromWorkspace() {
        let clean = Workspace(repoID: RepoID("r"), name: "n", branch: "b", path: "/p", baseBranch: "main")
        var numbered = clean
        numbered.pullRequestNumber = 7

        var schedule = PullRequestPollSchedule()
        let untouched = schedule.due(
            rows: [PullRequestPollSchedule.Row(clean, hasReadPullRequest: false, isDrawn: true)], now: start
        )
        let read = schedule.due(
            rows: [PullRequestPollSchedule.Row(clean, hasReadPullRequest: true, isDrawn: true)], now: start
        )
        var other = PullRequestPollSchedule()
        let recorded = other.due(
            rows: [PullRequestPollSchedule.Row(numbered, hasReadPullRequest: false, isDrawn: true)], now: start
        )
        #expect(untouched.isEmpty)
        #expect(read == [clean.id])
        #expect(recorded == [clean.id])
    }
}
