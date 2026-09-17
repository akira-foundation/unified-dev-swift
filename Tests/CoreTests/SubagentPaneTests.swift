import Testing
import Foundation
@testable import Core

@Suite struct SubagentKindTests {
    static let agentLine = """
    {"type":"system","subtype":"task_started","task_id":"ae8b434e1a270eeac",\
    "tool_use_id":"toolu_01Y1","description":"Count lines in a.txt",\
    "subagent_type":"general-purpose","is_backgrounded":false,"spawn_depth":1,\
    "task_type":"local_agent","prompt":"Read the file a.txt and report its line count."}
    """

    static let commandLine = """
    {"type":"system","subtype":"task_started","task_id":"bpx5joeoj",\
    "tool_use_id":"toolu_01KuPv","description":"Commit composer.json metadata change",\
    "task_type":"local_bash"}
    """

    private func subagent(_ line: String) throws -> Subagent {
        let json = try #require(JSONValue.parse(line))
        let signal = try #require(SubagentSignal.decode(json))
        var roster = SubagentRoster()
        roster.apply(signal)
        return try #require(roster.subagents.first)
    }

    @Test func aTaskSubagentIsAnAgent() throws {
        let agent = try subagent(Self.agentLine)
        #expect(agent.taskType == "local_agent")
        #expect(agent.kind == .agent)
        #expect(agent.kind.writesTranscript)
    }

    @Test func aBackgroundedShellCommandIsNotAnAgent() throws {
        let command = try subagent(Self.commandLine)
        #expect(command.taskType == "local_bash")
        #expect(command.kind == .command)
        #expect(!command.kind.writesTranscript)
    }

    @Test func aBackgroundCommandCarriesNoneOfAnAgentsFields() throws {
        let command = try subagent(Self.commandLine)
        #expect(command.prompt.isEmpty)
        #expect(command.type.isEmpty)
        #expect(!command.description.isEmpty)
    }

    @Test func anUnknownTaskTypeIsTreatedAsAnAgent() {
        #expect(SubagentKind(taskType: "") == .agent)
        #expect(SubagentKind(taskType: "remote_agent") == .agent)
        #expect(SubagentKind(taskType: "local_bash_v2") == .agent)
        #expect(SubagentKind(taskType: "local_bash") == .command)
    }
}

@Suite struct SubagentPaneTests {
    private func agent(
        type: String = "Explore", depth: Int = 1, seconds: Int = 0, state: SubagentState = .running
    ) -> Subagent {
        Subagent(id: SubagentID("a"), description: "Find the call sites", type: type,
                 spawnDepth: depth, prompt: "Find every call site.", taskType: "local_agent",
                 state: state, elapsedSeconds: seconds)
    }

    private func command(seconds: Int = 0) -> Subagent {
        Subagent(id: SubagentID("b"), description: "Build frontend assets",
                 taskType: "local_bash", elapsedSeconds: seconds)
    }

    @Test func aBackgroundCommandNoLongerCallsItselfASubagent() {
        let subtitle = SubagentPane.subtitle(command(seconds: 12))
        #expect(subtitle == "background command . 12s")
        #expect(!subtitle.contains("subagent"))
    }

    @Test func anAgentLeadsWithItsType() {
        #expect(SubagentPane.subtitle(agent(seconds: 5)) == "Explore . 5s")
    }

    @Test func depthIsSaidOnlyWhenItIsPastOne() {
        #expect(!SubagentPane.subtitle(agent(depth: 1)).contains("depth"))
        #expect(SubagentPane.subtitle(agent(depth: 3)).contains("depth 3"))
    }

    @Test func anAgentWithNoTypeFallsBackToTheNoun() {
        #expect(SubagentPane.subtitle(agent(type: "")).hasPrefix("subagent"))
    }

    @Test func theHeadingsMatchWhatTheThingActuallyIs() {
        #expect(SubagentPane.briefLabel(.agent) == "Asked")
        #expect(SubagentPane.briefLabel(.command) == "Ran")
        #expect(SubagentPane.outputLabel(.command) == "Printed")
    }

    @Test func aPromptIsProseAndACommandLineIsNot() {
        #expect(!SubagentPane.briefIsCode(.agent))
        #expect(SubagentPane.briefIsCode(.command))
    }

    @Test func aRunningSubagentKeepsBeingRead() {
        #expect(SubagentPane.refreshes(agent(state: .running)))
    }

    @Test func aFinishedSubagentIsNotPolled() {
        #expect(!SubagentPane.refreshes(agent(state: .completed)))
        #expect(!SubagentPane.refreshes(agent(state: .failed)))
        #expect(!SubagentPane.refreshes(agent(state: .stopped)))
        #expect(!SubagentPane.refreshes(nil))
    }

    @Test func theRefreshIsTheSameSecondTheRowCountsIn() {
        #expect(SubagentPane.refreshSeconds == 1.0)
    }

    @Test func aShortBriefIsNotHiddenBehindAClick() {
        let short = "Read a.txt and report its line count."
        #expect(!SubagentPane.briefCollapses(short))
    }

    @Test func aLongBriefOpensShutRatherThanShowingItsHead() {
        let long = String(repeating: "word ", count: 400)
        #expect(SubagentPane.briefCollapses(long))
    }

    @Test func theLineThatOpensABriefNamesWhatItHides() {
        #expect(SubagentPane.briefToggle(isExpanded: false, kind: .agent) == "Show the prompt")
        #expect(SubagentPane.briefToggle(isExpanded: true, kind: .agent) == "Hide the prompt")
        #expect(SubagentPane.briefToggle(isExpanded: false, kind: .command) == "Show the command")
        #expect(SubagentPane.briefToggle(isExpanded: true, kind: .command) == "Hide the command")
    }

    @Test func theCommandIsReadOffTheParentsToolCall() {
        let payload = Data("""
        {"type":"assistant","message":{"id":"msg_1","content":[{"type":"tool_use",\
        "id":"toolu_01KuPv","name":"Bash","input":{"command":"npm run build",\
        "description":"Build frontend assets","run_in_background":true}}]}}
        """.utf8)
        #expect(SubagentPane.commandLine(inPayload: payload) == "npm run build")
    }

    @Test func aToolCallWithNoCommandAnswersNothingRatherThanEmptyText() {
        let payload = Data("""
        {"type":"assistant","message":{"id":"msg_1","content":[{"type":"tool_use",\
        "id":"toolu_1","name":"Read","input":{"file_path":"/tmp/a.txt"}}]}}
        """.utf8)
        #expect(SubagentPane.commandLine(inPayload: payload) == nil)
        #expect(SubagentPane.commandLine(inPayload: Data("not json".utf8)) == nil)
        #expect(SubagentPane.commandLine(inPayload: Data()) == nil)
    }
}

@Suite(.scratchDirectory) struct SubagentOutputReadingTests {
    private static let session = SessionID("s1")

    private func write(_ text: String, _ name: String = "out") throws -> String {
        let dir = URL(fileURLWithPath: TestScratch.unique("subagent"))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    @Test func aCommandsStdoutIsNotParsedAsATranscript() throws {
        let path = try write("> build\nassets written in 1.2s\n")
        let asTranscript = SubagentOutput.read(path: path, kind: .agent, sessionID: Self.session)
        #expect(try asTranscript.get().isEmpty)

        let printed = try SubagentOutput.read(path: path, kind: .command, sessionID: Self.session).get()
        #expect(printed.messages.isEmpty)
        #expect(printed.printed == "> build\nassets written in 1.2s")
    }

    @Test func anAgentsFileIsStillParsedAsNDJSON() throws {
        let path = try write("""
        {"type":"user","message":{"role":"user","content":"Count the lines"}}
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"3"}]}}
        """)
        let transcript = try SubagentOutput.read(path: path, kind: .agent, sessionID: Self.session).get()
        #expect(transcript.prompt == "Count the lines")
        #expect(transcript.messages.map(\.kind) == [.assistantText])
    }

    @Test func aCommandThatPrintedNothingIsEmptyRatherThanABlankBlock() throws {
        let path = try write("   \n\n")
        #expect(try SubagentOutput.read(path: path, kind: .command, sessionID: Self.session).get().isEmpty)
    }

    @Test func theFailureSentencesKnowWhatTheyAreTalkingAbout() {
        #expect(SubagentOutput.Failure.noFile.sentence(.agent).contains("subagent"))
        let command = SubagentOutput.Failure.noFile.sentence(.command)
        #expect(!command.contains("subagent"))
        #expect(command.contains("command"))
        #expect(SubagentOutput.Failure.missing.sentence(.command) == "This command has not printed anything yet.")
        for kind in SubagentKind.allCases {
            for failure: SubagentOutput.Failure in [.noFile, .missing, .unreadable("The file could not be opened.")] {
                #expect(failure.sentence(kind).hasSuffix("."))
                #expect(!failure.sentence(kind).contains("\u{2014}"))
                #expect(!failure.sentence(kind).contains("\u{2013}"))
            }
        }
    }

    @Test func aRunningSubagentIsReadFromTheStreamAlreadyStored() {
        let lines = [
            #"{"type":"assistant","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"text","text":"Reading the diff"}]}}"#,
            #"{"type":"assistant","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_2","name":"Read","input":{"file_path":"/a/b.php"}}]}}"#,
            #"{"type":"user","parent_tool_use_id":"toolu_1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_2","content":"<?php"}]}}"#,
        ].map { Data($0.utf8) }

        let live = SubagentTranscript.live(streamLines: lines, sessionID: Self.session)
        #expect(live.messages.map(\.kind) == [.assistantText, .toolUse, .toolResult])
        #expect(live.messages[0].payload == lines[0])
        #expect(live.messages[2].refID == "toolu_2")

        #expect(SubagentTranscript.live(streamLines: [], sessionID: Self.session).isEmpty)
    }

    @Test func theBriefOnTheLiveStreamIsNotReadBackAsAnAnswer() {
        let lines = [
            #"{"type":"user","parent_tool_use_id":"toolu_1","message":{"role":"user","content":[{"type":"text","text":"You are implementing Tasks 7 and 8 of a plan for Assign."}]}}"#,
            #"{"type":"assistant","parent_tool_use_id":"toolu_1","message":{"role":"assistant","content":[{"type":"text","text":"Both tasks are in."}]}}"#,
        ].map { Data($0.utf8) }

        let live = SubagentTranscript.live(streamLines: lines, sessionID: Self.session)
        #expect(live.prompt == "You are implementing Tasks 7 and 8 of a plan for Assign.")
        #expect(live.messages.count == 1)
        #expect(live.messages[0].kind == .assistantText)
    }

    @Test func aWorkingSubagentWithNothingToShowIsNotDescribedAsAFailure() {
        #expect(SubagentPane.nothingToShow(.noFile, kind: .agent, isRunning: true)
            == "It has not said anything yet.")
        #expect(SubagentPane.nothingToShow(.noFile, kind: .command, isRunning: true)
            == "It has not printed anything yet.")
        #expect(SubagentPane.nothingToShow(.noFile, kind: .agent, isRunning: false)
            == SubagentOutput.Failure.noFile.sentence(.agent))
    }

    @Test func aFileThatIsNotThereIsASentenceRatherThanAThrow() {
        #expect(SubagentOutput.read(path: "/no/such/file", kind: .command, sessionID: Self.session)
            == .failure(.missing))
        #expect(SubagentOutput.read(path: "", kind: .command, sessionID: Self.session)
            == .failure(.noFile))
        #expect(SubagentOutput.read(path: nil, kind: .agent, sessionID: Self.session)
            == .failure(.noFile))
    }

    @Test func onlyTheTailOfALongFileIsRead() throws {
        let line = String(repeating: "x", count: 999) + "\n"
        let path = try write("FIRST" + String(repeating: line, count: 400))
        let text = try SubagentOutput.tail(of: URL(fileURLWithPath: path))
        #expect(text.count <= SubagentOutput.tailBytes)
        #expect(!text.contains("FIRST"))
    }

    @Test func aShortFileIsReadFromItsFirstByte() throws {
        let path = try write("FIRST\nsecond\n")
        #expect(try SubagentOutput.tail(of: URL(fileURLWithPath: path)).hasPrefix("FIRST"))
    }

    @Test func thePartialLineAtTheCutIsDropped() throws {
        let filler = String(repeating: "y", count: SubagentOutput.tailBytes)
        let path = try write("head\n" + filler + "\ntail line\n")
        let text = try SubagentOutput.tail(of: URL(fileURLWithPath: path))
        #expect(!text.hasPrefix("y"))
        #expect(text.hasSuffix("tail line\n"))
    }

    @Test func aTranscriptIsCappedAtWhatThePaneWillDraw() {
        let many = (0..<(SubagentTranscript.rowLimit + 30)).map {
            #"{"type":"assistant","uuid":"u\#($0)","message":{"content":[{"type":"text","text":"step"}]}}"#
        }.joined(separator: "\n")
        let transcript = SubagentTranscript.parse(many, sessionID: Self.session)
        #expect(transcript.messages.count == SubagentTranscript.rowLimit)
        #expect(transcript.droppedRows == 30)
    }

    @Test func anOrdinaryTranscriptReportsNothingDropped() {
        #expect(SubagentTranscript.parse("", sessionID: Self.session).droppedRows == 0)
    }
}
