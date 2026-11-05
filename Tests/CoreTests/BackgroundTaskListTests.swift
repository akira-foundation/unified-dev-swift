import Testing
import Foundation
@testable import Core

@Suite struct BackgroundTaskListTests {
    private static let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func task(
        _ id: String,
        taskType: String = "local_bash",
        state: SubagentState = .running,
        startedAt: TimeInterval = 0,
        finishedAt: TimeInterval? = nil
    ) -> Subagent {
        Subagent(
            id: SubagentID(id),
            description: "Task \(id)",
            taskType: taskType,
            state: state,
            finishedAt: finishedAt.map { Self.start.addingTimeInterval($0) },
            startedAt: Self.start.addingTimeInterval(startedAt)
        )
    }

    private func ids(_ list: BackgroundTaskList) -> [String] { list.rows.map(\.id.rawValue) }

    @Test func runningTasksComeFirstOldestFirstThenFinishedNewestFirst() {
        let roster = SubagentRoster([
            task("done-early", state: .completed, startedAt: 0, finishedAt: 5),
            task("late-runner", startedAt: 20),
            task("done-late", state: .failed, startedAt: 1, finishedAt: 30),
            task("early-runner", startedAt: 2),
        ])
        let list = BackgroundTaskList(roster, now: Self.start.addingTimeInterval(40))
        #expect(ids(list) == ["early-runner", "late-runner", "done-late", "done-early"])
        #expect(list.runningCount == 2)
    }

    @Test func commandsAndSubagentsAreListedTogether() {
        let roster = SubagentRoster([task("shell"), task("agent", taskType: "local_agent")])
        let list = BackgroundTaskList(roster, now: Self.start)
        #expect(list.rows.map(\.kind) == [.command, .agent])
    }

    @Test func openingSaysWhatWillBeShown() {
        let list = BackgroundTaskList(SubagentRoster([task("shell"), task("agent", taskType: "local_agent")]))
        #expect(list.rows.map(\.openHelp) == ["Show what this command printed", SubagentRunLink.openHelp])
    }

    @Test func onlyARunningTaskOffersStop() {
        let roster = SubagentRoster([
            task("1"),
            task("2", state: .completed, finishedAt: 1),
            task("3", state: .stopped, finishedAt: 1),
        ])
        let list = BackgroundTaskList(roster, stopsTasks: true, now: Self.start)
        #expect(list.rows.map(\.canStop) == [true, false, false])
    }

    @Test func aRunnerThatCannotStopTasksOffersNoStop() {
        let list = BackgroundTaskList(SubagentRoster([task("1")]), stopsTasks: false, now: Self.start)
        #expect(list.rows.map(\.canStop) == [false])
    }

    @Test func theDetailSaysWhatItIsWhereItStandsAndHowLong() {
        let roster = SubagentRoster([
            task("1", startedAt: 0),
            task("2", taskType: "local_agent", state: .failed, startedAt: 0, finishedAt: 75),
        ])
        let list = BackgroundTaskList(roster, now: Self.start.addingTimeInterval(12))
        #expect(list.rows.map(\.detail) == ["Background command · Running · 12s", "Subagent · Failed · 1m 15s"])
    }

    @Test func aTaskWithNoTimeYetLeavesTheDurationOut() {
        let list = BackgroundTaskList(SubagentRoster([task("1")]), now: Self.start)
        #expect(list.rows.map(\.detail) == ["Background command · Running"])
    }

    @Test func thePillCountsWhatIsRunningAndOtherwiseEverything() {
        #expect(BackgroundTaskList(SubagentRoster(), now: Self.start).label == nil)
        #expect(BackgroundTaskList(SubagentRoster([task("1"), task("2")]), now: Self.start).label == "2 running")

        let finished = SubagentRoster([task("1", state: .completed, finishedAt: 1)])
        #expect(BackgroundTaskList(finished, now: Self.start).label == "1 task")
        let several = SubagentRoster([
            task("1", state: .completed, finishedAt: 1), task("2", state: .failed, finishedAt: 2),
        ])
        #expect(BackgroundTaskList(several, now: Self.start).label == "2 tasks")
        #expect(BackgroundTaskList(several, now: Self.start).spokenLabel == "2 background tasks")

        let mixed = SubagentRoster([task("1"), task("2", state: .completed, finishedAt: 1)])
        #expect(BackgroundTaskList(mixed, now: Self.start).label == "1 running")
        #expect(BackgroundTaskList(mixed, now: Self.start).spokenLabel == "2 background tasks, 1 running")
        #expect(BackgroundTaskList(SubagentRoster([task("1")]), now: Self.start).spokenLabel
            == "1 background task, 1 running")
    }

    @Test func aTaskFinishedTwiceAcrossTurnsIsKeptOnce() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent")))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed", summary: "first")))
        roster.turnStarted()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent", resumesExisting: true)))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "failed", summary: "second")))
        roster.turnStarted()

        #expect(roster.history.map(\.id) == [SubagentID("a")])
        #expect(roster.task(SubagentID("a"))?.state == .failed)
        #expect(ids(BackgroundTaskList(roster)) == ["a"])
    }

    @Test func theLiveTaskWinsOverItsOwnHistory() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent")))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed")))
        roster.turnStarted()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent", resumesExisting: true)))
        #expect(roster.task(SubagentID("a"))?.state == .running)
    }

    @Test func aFinishedTaskWithNoEndTimeSortsByWhenItStarted() {
        let roster = SubagentRoster([
            task("old", state: .completed, startedAt: 1),
            task("new", state: .completed, startedAt: 9),
            task("ended", state: .completed, startedAt: 0, finishedAt: 5),
        ])
        #expect(ids(BackgroundTaskList(roster, now: Self.start)) == ["new", "ended", "old"])
    }

    @Test func runningAndFinishedAreSeparateSections() {
        let roster = SubagentRoster([
            task("finished", state: .completed, finishedAt: 5),
            task("failed", state: .failed, finishedAt: 6),
            task("runner"),
        ])
        let list = BackgroundTaskList(roster, now: Self.start.addingTimeInterval(10))
        #expect(list.running.map(\.id.rawValue) == ["runner"])
        #expect(list.finished.map(\.id.rawValue) == ["failed", "finished"])
    }

    @Test func onlyFinishedTasksCanBeCleared() {
        #expect(!BackgroundTaskList(SubagentRoster(), now: Self.start).canClear)
        #expect(!BackgroundTaskList(SubagentRoster([task("runner")]), now: Self.start).canClear)
        let finished = SubagentRoster([task("runner"), task("done", state: .completed, finishedAt: 1)])
        #expect(BackgroundTaskList(finished, now: Self.start).canClear)
    }

    private func cleared(_ roster: SubagentRoster) -> ClearedBackgroundTasks {
        var cleared = ClearedBackgroundTasks()
        cleared.clear(roster)
        return cleared
    }

    @Test func clearingHidesEveryFinishedTaskAndKeepsTheRunningOnes() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("earlier"), taskType: "local_bash")))
        roster.apply(.reported(SubagentReport(id: SubagentID("earlier"), status: "completed")))
        roster.turnStarted()
        roster.apply(.started(SubagentStart(id: SubagentID("failed"), taskType: "local_agent")))
        roster.apply(.reported(SubagentReport(id: SubagentID("failed"), status: "failed")))
        roster.apply(.started(SubagentStart(id: SubagentID("stopped"), taskType: "local_bash")))
        roster.apply(.reported(SubagentReport(id: SubagentID("stopped"), status: "stopped")))
        roster.apply(.started(SubagentStart(id: SubagentID("runner"), taskType: "local_bash")))

        let list = BackgroundTaskList(roster, cleared: cleared(roster))

        #expect(ids(list) == ["runner"])
        #expect(!list.canClear)
    }

    @Test func aTaskRunningAtTheClearIsListedWhenItFinishes() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("runner"), taskType: "local_bash")))
        let clearedTasks = cleared(roster)
        roster.apply(.reported(SubagentReport(id: SubagentID("runner"), status: "failed")))
        #expect(ids(BackgroundTaskList(roster, cleared: clearedTasks)) == ["runner"])
    }

    @Test func aClearedTaskResumedAndFinishedAgainIsListedAgain() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent")))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed")))
        var clearedTasks = cleared(roster)
        #expect(BackgroundTaskList(roster, cleared: clearedTasks).isEmpty)

        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent", resumesExisting: true)))
        clearedTasks.forgetRunning(in: roster)
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed")))
        #expect(ids(BackgroundTaskList(roster, cleared: clearedTasks)) == ["a"])
    }

    @Test func aClearedTaskStaysHiddenAfterARecoveryHandsTheRosterBack() {
        let original = SubagentRoster([task("done", state: .completed, finishedAt: 1)])
        let clearedTasks = cleared(original)
        let recovered = SubagentRoster([task("done", state: .completed, finishedAt: 9)])
        #expect(BackgroundTaskList(recovered, cleared: clearedTasks).isEmpty)
    }

    @Test func clearingTheLastTaskLeavesNothingToShow() {
        let roster = SubagentRoster([task("done", state: .completed, finishedAt: 1)])
        let clearedTasks = cleared(roster)
        let list = BackgroundTaskList(roster, cleared: clearedTasks)
        #expect(list.isEmpty)
        #expect(list.label == nil)
        #expect(list.spokenLabel == nil)
        #expect(!clearedTasks.hasVisibleTasks(in: roster))
    }

    @Test func aRunningTaskKeepsTheListVisibleAfterAClear() {
        let roster = SubagentRoster([task("runner"), task("done", state: .completed, finishedAt: 1)])
        #expect(cleared(roster).hasVisibleTasks(in: roster))
    }

    @Test func clearingLeavesTheRosterItselfAlone() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), toolUseID: "use-a", taskType: "local_agent")))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed")))
        let before = roster
        _ = cleared(roster)
        #expect(roster == before)
    }

    @Test func aRosterWithOnlyHistoryStillHasTasks() {
        var roster = SubagentRoster()
        #expect(!ClearedBackgroundTasks().hasVisibleTasks(in: roster))
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_bash")))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed")))
        roster.turnStarted()
        #expect(roster.subagents.isEmpty)
        #expect(ClearedBackgroundTasks().hasVisibleTasks(in: roster))
    }

    @Test func aTaskFinishedInAnEarlierTurnIsStillListed() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("build"), description: "Build", taskType: "local_bash")))
        roster.apply(.reported(SubagentReport(id: SubagentID("build"), status: "completed")))
        roster.turnStarted()
        roster.apply(.started(SubagentStart(id: SubagentID("test"), description: "Test", taskType: "local_bash")))

        #expect(roster.subagents.map(\.id) == [SubagentID("test")])
        #expect(ids(BackgroundTaskList(roster)) == ["test", "build"])
        #expect(roster.task(SubagentID("build"))?.state == .completed)
        #expect(roster[SubagentID("build")] == nil)
    }

    @Test func aRunningTaskIsNotMovedToTheHistory() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("serve"), taskType: "local_bash")))
        roster.turnStarted()
        #expect(roster.history.isEmpty)
        #expect(roster.runningCommands.map(\.id) == [SubagentID("serve")])
    }

    @Test func theHistoryKeepsOnlyTheNewestTasks() {
        var roster = SubagentRoster()
        for index in 0..<(SubagentRoster.historyLimit + 5) {
            let id = SubagentID("t\(index)")
            roster.apply(.started(SubagentStart(id: id, taskType: "local_bash")))
            roster.apply(.reported(SubagentReport(id: id, status: "completed")))
            roster.turnStarted()
        }
        #expect(roster.history.count == SubagentRoster.historyLimit)
        #expect(roster.history.first?.id == SubagentID("t5"))
    }

    @Test func aResumedTaskIsListedOnceAsTheLiveOne() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent")))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed")))
        roster.turnStarted()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), taskType: "local_agent", resumesExisting: true)))

        let list = BackgroundTaskList(roster)
        #expect(ids(list) == ["a"])
        #expect(list.runningCount == 1)
    }
}
