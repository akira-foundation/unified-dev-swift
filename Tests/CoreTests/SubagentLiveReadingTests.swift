import Foundation
import Testing
@testable import Core

@Suite("Reading a running subagent from the parent's stream")
struct SubagentLiveReadingTests {
    private let call = Data(#"{"type":"assistant","parent_tool_use_id":"toolu_task","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_read","name":"Read","input":{"file_path":"maps/north.md"}}]}}"#.utf8)
    private let result = Data(#"{"type":"user","parent_tool_use_id":"toolu_task","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_read","content":"Fjords."}]}}"#.utf8)

    @Test func aCallsResultTravelsRightAfterIt() {
        let lines = SubagentTranscript.streamLines([(call, result)])
        #expect(lines == [call, result])
    }

    @Test func aCallStillWaitingSendsOnlyItself() {
        #expect(SubagentTranscript.streamLines([(call, nil)]) == [call])
    }

    @Test func theLiveReadingPairsTheResultWithItsCall() {
        let lines = SubagentTranscript.streamLines([(call, result)])
        let reading = SubagentTranscript.live(streamLines: lines, sessionID: SessionID("s"))
        #expect(reading.messages.map(\.kind) == [.toolUse, .toolResult])
        #expect(reading.messages.last?.refID == "toolu_read")
    }
}
