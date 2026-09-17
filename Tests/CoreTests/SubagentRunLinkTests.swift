import Foundation
import Testing
@testable import Core

@Suite("Opening a subagent's run from its call")
struct SubagentRunLinkTests {
    private func none() -> SubagentID? { nil }

    @Test("the roster's subagent is preferred while it still holds one")
    func liveWins() {
        let target = SubagentRunLink.target(
            toolUseID: "toolu_1", hasRecordedRows: true, isSettled: true, liveID: { SubagentID("task") }
        )
        #expect(target == .live(SubagentID("task")))
    }

    @Test("a finished subagent the roster has forgotten opens from its stored rows")
    func forgottenOpensRecorded() {
        let target = SubagentRunLink.target(
            toolUseID: "toolu_1", hasRecordedRows: true, isSettled: true, liveID: none
        )
        #expect(target == .recorded(toolUseID: "toolu_1"))
    }

    @Test("a call still running opens even before its first row has landed")
    func runningOpens() {
        let target = SubagentRunLink.target(
            toolUseID: "toolu_1", hasRecordedRows: false, isSettled: false, liveID: none
        )
        #expect(target == .recorded(toolUseID: "toolu_1"))
    }

    @Test("a finished call with nothing kept under it is unavailable rather than an empty pane")
    func nothingKept() {
        let target = SubagentRunLink.target(
            toolUseID: "toolu_1", hasRecordedRows: false, isSettled: true, liveID: none
        )
        #expect(target == .unavailable)
        #expect(SubagentRunLink.target(toolUseID: nil, hasRecordedRows: true, isSettled: false, liveID: none) == .unavailable)
        #expect(SubagentRunLink.target(toolUseID: "", hasRecordedRows: true, isSettled: false, liveID: none) == .unavailable)
    }

    @Test(
        "whether the row offers to open agrees with what opening finds",
        arguments: [true, false], [true, false]
    )
    func canOpenAgreesWithTarget(hasRows: Bool, isSettled: Bool) {
        for live in [true, false] {
            for id in ["toolu_1", "", nil] as [String?] {
                let target = SubagentRunLink.target(
                    toolUseID: id, hasRecordedRows: hasRows, isSettled: isSettled,
                    liveID: { live ? SubagentID("task") : nil }
                )
                let offered = SubagentRunLink.canOpen(
                    toolUseID: id, hasRecordedRows: hasRows, isSettled: isSettled, isLive: { _ in live }
                )
                #expect(offered == (target != .unavailable), "live \(live), id \(String(describing: id))")
            }
        }
    }

    @Test("the roster is not read when the stored rows already answer")
    func rosterAskedLast() {
        var asked = false
        let offered = SubagentRunLink.canOpen(
            toolUseID: "toolu_1", hasRecordedRows: true, isSettled: true, isLive: { _ in
                asked = true
                return false
            }
        )
        #expect(offered)
        #expect(!asked)
    }

    @Test("the pane's header is read off the call that started the subagent")
    func recordedSubagentReadsTheCall() throws {
        let input = try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"description":"Build shimmer","subagent_type":"general-purpose","prompt":"Do the thing"}
        """.utf8))
        let started = Date(timeIntervalSince1970: 1_000)
        let done = SubagentRunLink.recordedSubagent(
            toolUseID: "toolu_1", input: input, startedAt: started, isSettled: true, failed: false, durationMS: 95_400
        )
        #expect(done.toolUseID == "toolu_1")
        #expect(done.description == "Build shimmer")
        #expect(done.type == "general-purpose")
        #expect(done.prompt == "Do the thing")
        #expect(done.kind == .agent)
        #expect(done.state == .completed)
        #expect(done.secondsElapsed(at: started.addingTimeInterval(10_000)) == 95)

        let running = SubagentRunLink.recordedSubagent(
            toolUseID: "toolu_1", input: nil, startedAt: started, isSettled: false, failed: false, durationMS: nil
        )
        #expect(running.state == .running)
        #expect(SubagentPane.refreshes(running))

        let failed = SubagentRunLink.recordedSubagent(
            toolUseID: "toolu_1", input: nil, startedAt: started, isSettled: true, failed: true, durationMS: nil
        )
        #expect(failed.state == .failed)
    }

    @Test("only a call that starts a subagent is an Agent call")
    func agentCalls() {
        #expect(SubagentRunLink.isAgentCall(toolName: "Task"))
        #expect(SubagentRunLink.isAgentCall(toolName: "Agent"))
        #expect(!SubagentRunLink.isAgentCall(toolName: "Bash"))
    }

    @Test("the roster finds a subagent by the call that started it, until it forgets it")
    func rosterLookup() {
        var roster = SubagentRoster([
            Subagent(id: SubagentID("t1"), toolUseID: "toolu_1", state: .completed),
            Subagent(id: SubagentID("t2"), toolUseID: "toolu_2"),
        ])
        #expect(roster.subagent(forToolUseID: "toolu_1")?.id == SubagentID("t1"))
        #expect(roster.subagent(forToolUseID: "") == nil)
        roster.turnStarted()
        #expect(roster.subagent(forToolUseID: "toolu_1") == nil)
        #expect(roster.subagent(forToolUseID: "toolu_2")?.id == SubagentID("t2"))
    }

    @Test("a run is known from any stored row, prose included")
    func hasRunFromProse() {
        let facts = [
            TranscriptFold.Fact(seq: 0, kind: .user),
            TranscriptFold.Fact(seq: 1, kind: .toolUse, settled: true, toolUseID: "a"),
            TranscriptFold.Fact(seq: 2, kind: .assistantText, parentToolUseID: "a"),
            TranscriptFold.Fact(seq: 3, kind: .toolUse, toolUseID: "b"),
        ]
        let folds = TranscriptFold.folds(in: facts)
        #expect(folds.hasRun(underCall: "a"))
        #expect(folds.actions(underCall: "a") == nil)
        #expect(!folds.hasRun(underCall: "b"))
        #expect(!folds.hasRun(underCall: nil))
    }
}
