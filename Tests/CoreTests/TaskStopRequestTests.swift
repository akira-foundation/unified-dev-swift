import Testing
import Foundation
@testable import Core

@Suite struct TaskStopRequestTests {
    @Test func asksTheCLIToStopOneTaskByItsID() throws {
        let line = try TaskStopRequest.encode(taskID: SubagentID("bnvof6952"), requestID: "req-1")
        let json = try #require(JSONValue.parse(line))
        #expect(json["type"]?.stringValue == "control_request")
        #expect(json["request_id"]?.stringValue == "req-1")
        #expect(json["request"]?["subtype"]?.stringValue == "stop_task")
        #expect(json["request"]?["task_id"]?.stringValue == "bnvof6952")
        #expect(!line.contains("\n"))
    }

    @Test func everyRequestGetsItsOwnID() throws {
        let first = try #require(JSONValue.parse(try TaskStopRequest.encode(taskID: SubagentID("a"))))
        let second = try #require(JSONValue.parse(try TaskStopRequest.encode(taskID: SubagentID("a"))))
        #expect(first["request_id"]?.stringValue != second["request_id"]?.stringValue)
    }
}
