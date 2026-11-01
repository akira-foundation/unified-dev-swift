import Testing
import Foundation
@testable import Core

@Suite(.scratchDirectory) struct CodexBackgroundCommandsTests {
    private let thread = "01a19701-7214-7433-9496-12c3783e0b07"
    private let turn = "01a19701-72d7-7b41-8666-c0091a3985a0"
    private let item = "exec-4e516cb6-7b49-4d7e-8fab-2f9da56bffd3"

    private func event(_ method: String, _ params: String) throws -> CodexEvent {
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(params.utf8))
        return CodexEvent.decode(CodexServerNotification(method: method, params: json))
    }

    private func started(threadID: String? = nil) throws -> CodexEvent {
        try event("item/started", #"""
        {"threadId":"\#(threadID ?? thread)","turnId":"\#(turn)","item":{"type":"commandExecution","id":"\#(item)",
         "command":"/bin/zsh -lc 'sleep 45; echo pronto'","status":"inProgress","processId":"76979"}}
        """#)
    }

    private func turnCompleted(id: String? = nil, threadID: String? = nil, status: String = "completed") throws -> CodexEvent {
        try event("turn/completed", #"""
        {"threadId":"\#(threadID ?? thread)","turn":{"id":"\#(id ?? turn)","status":"\#(status)","items":[]}}
        """#)
    }

    private func completed(exitCode: Int = 0, output: String = "pronto\n") throws -> CodexEvent {
        try event("item/completed", #"""
        {"threadId":"\#(thread)","turnId":"\#(turn)","item":{"type":"commandExecution","id":"\#(item)",
         "command":"/bin/zsh -lc 'sleep 45; echo pronto'","status":"completed","processId":"76979",
         "exitCode":\#(exitCode),"durationMs":44875,"aggregatedOutput":"\#(output.replacingOccurrences(of: "\n", with: "\\n"))"}}
        """#)
    }

    @Test func aCommandStillRunningWhenTheTurnEndsBecomesABackgroundCommand() throws {
        var tracker = CodexBackgroundCommands()
        #expect(tracker.receive(try started(), parentThreadID: thread).isEmpty)

        let changes = tracker.receive(try turnCompleted(), parentThreadID: thread)
        let id = CodexBackgroundCommands.id(for: item)
        #expect(changes == [.started(SubagentStart(
            id: id, description: "sleep 45; echo pronto", isBackgrounded: true, taskType: "local_bash"
        ))])

        let finished = tracker.receive(try completed(), parentThreadID: thread)
        #expect(finished == [.finished(id: id, status: "completed", summary: "exit 0", output: "pronto\n")])
    }

    @Test func aCommandThatEndsInsideItsTurnIsNeverABackgroundCommand() throws {
        var tracker = CodexBackgroundCommands()
        _ = tracker.receive(try started(), parentThreadID: thread)
        #expect(tracker.receive(try completed(), parentThreadID: thread).isEmpty)
        #expect(tracker.receive(try turnCompleted(), parentThreadID: thread).isEmpty)
    }

    @Test func aNonZeroExitIsAFailure() throws {
        var tracker = CodexBackgroundCommands()
        _ = tracker.receive(try started(), parentThreadID: thread)
        _ = tracker.receive(try turnCompleted(), parentThreadID: thread)
        let finished = tracker.receive(try completed(exitCode: 2, output: "boom\n"), parentThreadID: thread)
        #expect(finished == [.finished(
            id: CodexBackgroundCommands.id(for: item), status: "failed", summary: "exit 2", output: "boom\n"
        )])
    }

    @Test func aChildThreadsCommandIsNotThisChatsTask() throws {
        var tracker = CodexBackgroundCommands()
        _ = tracker.receive(try started(threadID: "child"), parentThreadID: thread)
        #expect(tracker.receive(try turnCompleted(), parentThreadID: thread).isEmpty)
    }

    @Test func theRosterFollowsTheCommandFromStartToFinish() throws {
        var tracker = CodexBackgroundCommands()
        var roster = SubagentRoster()
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        for event in [try started(), try turnCompleted(), try completed()] {
            for change in tracker.receive(event, parentThreadID: thread) {
                roster.apply(CodexRunner.signal(for: change, in: directory))
            }
        }
        let command = try #require(roster[CodexBackgroundCommands.id(for: item)])
        #expect(command.kind == .command)
        #expect(command.state == .completed)
        let path = try #require(command.outputFile)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "pronto\n")
        #expect(path.hasPrefix(directory.path))
    }

    @Test func theOutputFileNameKeepsOnlySafeCharacters() {
        let url = CodexBackgroundCommands.outputURL(
            for: SubagentID("codex-exec:../../etc/passwd"), in: URL(filePath: "/tmp/x")
        )
        #expect(url.deletingLastPathComponent().path == "/tmp/x")
        #expect(url.lastPathComponent == "codex-exec_______etc_passwd.output")
    }

    @Test(arguments: ["interrupted", "failed"])
    func aTurnThatDidNotCompleteKilledItsCommands(_ status: String) throws {
        var tracker = CodexBackgroundCommands()
        _ = tracker.receive(try started(), parentThreadID: thread)
        #expect(tracker.receive(try turnCompleted(status: status), parentThreadID: thread).isEmpty)
        #expect(tracker.receive(try completed(), parentThreadID: thread).isEmpty)
    }

    @Test func aLateEndForAReplacedTurnLeavesTheNextTurnsCommandsAlone() throws {
        var tracker = CodexBackgroundCommands()
        _ = tracker.receive(try started(), parentThreadID: thread)
        #expect(tracker.receive(try turnCompleted(id: "an-earlier-turn"), parentThreadID: thread).isEmpty)
        #expect(tracker.receive(try completed(), parentThreadID: thread).isEmpty)
    }

    @Test func aChildThreadsTurnEndingPromotesNothingOfOurs() throws {
        var tracker = CodexBackgroundCommands()
        _ = tracker.receive(try started(), parentThreadID: thread)
        #expect(tracker.receive(try turnCompleted(threadID: "child"), parentThreadID: thread).isEmpty)
        #expect(tracker.receive(try turnCompleted(), parentThreadID: thread).count == 1)
    }

    @Test func aCommandThatNeverStartedInThisChatIsIgnoredWhenItEnds() throws {
        var tracker = CodexBackgroundCommands()
        #expect(tracker.receive(try completed(), parentThreadID: thread).isEmpty)
    }

    @Test(arguments: [
        (CodexRunStatus.completed, Int?.some(0), "completed"),
        (.completed, nil, "completed"),
        (.completed, 1, "failed"),
        (.failed, 0, "failed"),
        (.declined, nil, "stopped"),
        (.unknown, 0, "completed"),
        (.unknown, nil, "failed"),
        (.inProgress, nil, "failed"),
    ])
    func theStatusSaysHowItEnded(_ status: CodexRunStatus, _ exitCode: Int?, _ expected: String) {
        let run = CodexCommandExecution(id: "x", command: "true", exitCode: exitCode, status: status)
        #expect(CodexBackgroundCommands.status(of: run) == expected)
    }

    @Test func aCommandWithNoExitCodeHasNoSummary() throws {
        var tracker = CodexBackgroundCommands()
        _ = tracker.receive(try started(), parentThreadID: thread)
        _ = tracker.receive(try turnCompleted(), parentThreadID: thread)
        let ended = try event("item/completed", #"""
        {"threadId":"\#(thread)","turnId":"\#(turn)","item":{"type":"commandExecution","id":"\#(item)",
         "command":"sleep 45","status":"failed"}}
        """#)
        let finished = tracker.receive(ended, parentThreadID: thread)
        #expect(finished == [.finished(id: CodexBackgroundCommands.id(for: item), status: "failed", summary: "", output: "")])
    }

    @Test func theOutputLivesBesideTheDatabase() {
        let directory = CodexBackgroundCommands.outputDirectory(besideDatabaseAt: "/work/.build/preview/data/unifieddev.sqlite")
        #expect(directory.path == "/work/.build/preview/data/codex-background-output")
    }

    @Test func onlyTheTailOfALongOutputIsKept() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let long = String(repeating: "a", count: SubagentOutput.tailBytes) + "the end"
        let signal = CodexRunner.signal(
            for: .finished(id: SubagentID("x"), status: "completed", summary: "", output: long), in: directory
        )
        guard case .reported(let report) = signal else { Issue.record("not a report"); return }
        let path = try #require(report.outputFile)
        let kept = try Data(contentsOf: URL(filePath: path))
        #expect(kept.count == SubagentOutput.tailBytes)
        #expect(String(decoding: kept, as: UTF8.self).hasSuffix("the end"))
    }

    @Test func anOutputThatCannotBeWrittenStillEndsTheTaskWithNoFile() throws {
        let blocker = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("a file, not a directory".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let signal = CodexRunner.signal(
            for: .finished(id: SubagentID("x"), status: "completed", summary: "exit 0", output: "pronto\n"),
            in: blocker
        )
        #expect(signal == .reported(SubagentReport(
            id: SubagentID("x"), status: "completed", summary: "exit 0", outputFile: nil
        )))
    }
}
