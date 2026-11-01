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
        let list = BackgroundTaskList(roster, now: Self.start)
        #expect(list.rows.map(\.canStop) == [true, false, false])
    }

    @Test func theDetailSaysWhatItIsWhereItStandsAndHowLong() {
        let roster = SubagentRoster([
            task("1", startedAt: 0),
            task("2", taskType: "local_agent", state: .failed, startedAt: 0, finishedAt: 75),
        ])
        let list = BackgroundTaskList(roster, now: Self.start.addingTimeInterval(12))
        #expect(list.rows.map(\.detail) == ["Command · Running · 12s", "Subagent · Failed · 1m 15s"])
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
    }

    @Test func aTaskFinishedInAnEarlierTurnIsStillListed() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("build"), description: "Build", taskType: "local_bash")))
        roster.apply(.reported(SubagentReport(id: SubagentID("build"), status: "completed")))
        roster.turnStarted()
        roster.apply(.started(SubagentStart(id: SubagentID("test"), description: "Test", taskType: "local_bash")))

        #expect(roster.subagents.map(\.id) == [SubagentID("test")])
        #expect(ids(BackgroundTaskList(roster)) == ["test", "build"])
        #expect(roster[SubagentID("build")]?.state == .completed)
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

    @Test func aFinishedTaskDoesNotReopenAsLiveFromTheTranscript() {
        var roster = SubagentRoster()
        roster.apply(.started(SubagentStart(id: SubagentID("a"), toolUseID: "toolu_1", taskType: "local_agent")))
        roster.apply(.reported(SubagentReport(id: SubagentID("a"), status: "completed")))
        roster.turnStarted()
        #expect(roster.subagent(forToolUseID: "toolu_1") == nil)
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
