import Foundation
import Testing
@testable import Core

@Suite("A call a hook refused")
struct HookRefusalTests {
    private static func toolResult(
        id: String = "toolu_01Xe8zVgK9CytscT6hxbKW3x",
        kind: String,
        decision: String = "reject",
        source: String
    ) -> String {
        """
        {"type":"user","message":{"role":"user","content":[{"type":"tool_result",\
        "content":"PreToolUse:Bash hook error: BLOCKED by a hook","is_error":true,\
        "tool_use_id":"\(id)"}]},"parent_tool_use_id":null,"session_id":"s","uuid":"u",\
        "tool_result_meta":[{"id":"\(id)","non_execution_kind":"\(kind)",\
        "permission_decision":{"decision":"\(decision)","source":"\(source)","reason_type":"hook"}}]}
        """
    }

    private static func result(denied ids: [String], isError: Bool = false) -> AgentResult? {
        let denials = ids
            .map { #"{"tool_name":"Bash","tool_use_id":"\#($0)","tool_input":{"command":"git commit"}}"# }
            .joined(separator: ",")
        let line = #"{"type":"result","subtype":"success","is_error":\#(isError),"permission_denials":[\#(denials)]}"#
        guard case .result(let value)? = AgentEvent.decode(line: line) else { return nil }
        return value
    }

    private static func refusal(of line: String) -> ToolRefusal? {
        guard case .toolResult(let value)? = AgentEvent.decode(line: line) else { return nil }
        return value.refusal
    }

    @Test("the line the CLI wrote for a refused commit reads as a hook")
    func theRecordedLine() {
        let line = Self.toolResult(kind: "permission-rule", source: "hook")

        #expect(Self.refusal(of: line) == .hookRefused)
        #expect(ToolResultSummary.decode(Data(line.utf8)).refusal == .hookRefused)
    }

    @Test("every other source keeps the denial", arguments: [
        "config", "user_reject", "user_temporary", "user_permanent",
    ])
    func otherSourcesStayDenied(source: String) {
        let line = Self.toolResult(kind: "permission-rule", source: source)

        #expect(Self.refusal(of: line) == .denied)
        #expect(ToolResultSummary.decode(Data(line.utf8)).refusal == .denied)
    }

    @Test("a line with no decision keeps the denial")
    func noDecisionStaysDenied() {
        #expect(ToolRefusal(protocolKind: "permission-rule") == .denied)
    }

    @Test("a decision with no refusal behind it is not a refusal")
    func decisionAloneIsNotARefusal() {
        #expect(ToolRefusal(protocolKind: nil, decision: "reject", decisionSource: "hook") == nil)
    }

    @Test("a hook on the next call of the same line does not excuse this one")
    func theDecisionBelongsToItsOwnCall() throws {
        let line = """
        {"type":"user","message":{"role":"user","content":[\
        {"type":"tool_result","content":"no","is_error":true,"tool_use_id":"real"},\
        {"type":"tool_result","content":"no","is_error":true,"tool_use_id":"hook"}]},\
        "tool_result_meta":[\
        {"id":"hook","non_execution_kind":"permission-rule",\
        "permission_decision":{"decision":"reject","source":"hook"}},\
        {"id":"real","non_execution_kind":"permission-rule",\
        "permission_decision":{"decision":"reject","source":"config"}}]}
        """

        #expect(ToolResultSummary.decode(Data(line.utf8)).refusal == .denied)
    }

    @Test("a call that ran does not hide the refusal beside it")
    func theFirstErroredCallDecides() {
        let line = """
        {"type":"user","message":{"role":"user","content":[\
        {"type":"tool_result","content":"fine","is_error":false,"tool_use_id":"ran"},\
        {"type":"tool_result","content":"no","is_error":true,"tool_use_id":"hook"}]},\
        "tool_result_meta":[{"id":"hook","non_execution_kind":"permission-rule",\
        "permission_decision":{"decision":"reject","source":"hook"}}]}
        """

        #expect(ToolResultSummary.decode(Data(line.utf8)).refusal == .hookRefused)
    }

    @Test("only a call a hook refused counts, and only with an id to match it by")
    func hookRefusedCallsAreNamed() {
        let calls: [(refID: String?, refusal: ToolRefusal?)] = [
            ("hook", .hookRefused), (nil, .hookRefused), ("owner", .denied), ("ran", nil), ("stopped", .stopped),
        ]

        #expect(ToolRefusal.hookRefusedCalls(calls) == ["hook"])
    }

    @Test("a turn that failed is a failure whatever a hook refused")
    func failureStaysAFailure() throws {
        let result = try #require(Self.result(denied: ["hook"], isError: true))

        #expect(result.outcome(wasCancelled: false, hookRefusedCalls: ["hook"]) == .failed)
    }

    @Test("a hook that allowed a call does not own what then happened to it")
    func allowedByHookThenStopped() {
        let line = Self.toolResult(kind: "interrupted", decision: "accept", source: "hook")

        #expect(Self.refusal(of: line) == .stopped)
    }

    @Test("the text of the message decides nothing")
    func textDecidesNothing() {
        let line = Self.toolResult(kind: "permission-rule", source: "config")

        #expect(line.contains("hook error"))
        #expect(Self.refusal(of: line) == .denied)
    }

    @Test("a hook refusal gives no advice about permission modes")
    func noAdvice() {
        #expect(ToolRefusal.hookRefused.remedy == nil)
        #expect(!ToolRefusal.hookRefused.summary.contains("permission"))
    }

    @Test("a turn whose only refusal was a hook finished")
    func onlyHookFinishes() throws {
        let result = try #require(Self.result(denied: ["hook"]))

        #expect(result.outcome(wasCancelled: false, hookRefusedCalls: ["hook"]) == .finished)
        #expect(result.permissionDenials(excluding: ["hook"]) == 0)
    }

    @Test("a real denial beside a hook refusal still asks for the person")
    func realDenialSurvives() throws {
        let result = try #require(Self.result(denied: ["hook", "rule"]))

        #expect(result.outcome(wasCancelled: false, hookRefusedCalls: ["hook"]) == .needsInput)
        #expect(result.permissionDenials(excluding: ["hook"]) == 1)
    }

    @Test("a denial nothing marked as a hook still asks for the person")
    func unmarkedDenialSurvives() throws {
        let result = try #require(Self.result(denied: ["rule"]))

        #expect(result.outcome(wasCancelled: false) == .needsInput)
        #expect(result.permissionDenials(excluding: []) == 1)
    }

    @Test("a hook refusal in another turn does not hide this turn's denial")
    func otherTurnsDoNotCount() throws {
        let result = try #require(Self.result(denied: ["rule"]))

        #expect(result.outcome(wasCancelled: false, hookRefusedCalls: ["hook"]) == .needsInput)
    }
}
