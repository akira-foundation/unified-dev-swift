import Testing
import Foundation
@testable import Core

@Suite("Stray results", .tags(.agentProtocol))
struct StrayResultTests {
    private static let asMeasured = #"""
    {"type":"result","subtype":"success","is_error":false,"duration_api_ms":0,"num_turns":0,\
    "stop_reason":null,"session_id":"b5261ad0","total_cost_usd":0,"result":"",\
    "origin":{"kind":"task-notification"},"duration_ms":60,"uuid":"db9d3351"}
    """#.replacingOccurrences(of: "\\\n", with: "")

    private func result(in line: String) -> AgentResult? {
        guard case .result(let result)? = AgentEvent.decode(line: line) else { return nil }
        return result
    }

    @Test("the origin the CLI names is read off the line")
    func readsOrigin() throws {
        #expect(try #require(result(in: Self.asMeasured)).origin == "task-notification")
    }

    @Test("the turn that ended in a tenth of a second closes nothing")
    func theBug() throws {
        #expect(StrayResult.isStray(try #require(result(in: Self.asMeasured))))
    }

    @Test("a result naming no origin is the owner's, whatever else it says")
    func unstatedIsOwners() {
        #expect(!StrayResult.isStray(AgentResult(numTurns: 0, durationAPIMS: 0)))
    }

    @Test("an origin on a turn that did real work is still the owner's")
    func workIsNeverStray() {
        #expect(!StrayResult.isStray(
            AgentResult(summary: "Pushed.", numTurns: 3, durationAPIMS: 4_200, origin: "whatever")
        ))
        #expect(!StrayResult.isStray(AgentResult(numTurns: 1, origin: "whatever")))
        #expect(!StrayResult.isStray(AgentResult(summary: "Nothing to commit.", origin: "whatever")))
    }

    @Test("a failure is never stray, however empty it is")
    func failuresAreNeverStray() {
        #expect(!StrayResult.isStray(
            AgentResult(isError: true, subtype: "error_during_execution", origin: "whatever")
        ))
    }

    @Test("a kind nobody has seen yet is caught by the same rule")
    func anyStatedOrigin() {
        #expect(StrayResult.isStray(AgentResult(origin: "hook")))
        #expect(StrayResult.isStray(AgentResult(origin: "task-notification")))
    }
}
