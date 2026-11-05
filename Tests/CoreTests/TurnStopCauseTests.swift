import Testing
import Foundation
@testable import Core

@Suite("Recognising a turn stopped by the usage limit")
struct TurnStopCauseTests {
    private let chat = SessionID("chat-stop-cause")

    private func row(_ seq: Int, _ kind: MessageKind, _ json: String) -> Message {
        Message(sessionID: chat, seq: seq, kind: kind, payload: Data(json.utf8))
    }

    private func owner(_ seq: Int, _ text: String = "go on") -> Message {
        row(seq, .user, #"{"type":"user","message":{"role":"user","content":"\#(text)"}}"#)
    }

    private func reply(_ seq: Int, _ text: String) -> Message {
        row(seq, .assistantText, #"{"type":"assistant","message":{"model":"claude-opus-5","role":"assistant","content":[{"type":"text","text":"\#(text)"}]}}"#)
    }

    private func claudeLimit(_ seq: Int, line: Int) throws -> Message {
        row(seq, .assistantText, try fixtureLines("claude-usage-limit.ndjson")[line])
    }

    private func closing(_ seq: Int) -> Message {
        row(seq, .result, #"{"type":"result","subtype":"success","is_error":true,"terminal_reason":"api_error","result":"You've hit your session limit"}"#)
    }

    @Test func theSessionLimitTheCliWasMeasuredWritingIsTheLimit() throws {
        let rows = [owner(1), try claudeLimit(2, line: 0), closing(3)]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .usageLimit)
    }

    @Test func theSameLimitWithItsQuotaWindowIsTheLimit() throws {
        let rows = [owner(1), try claudeLimit(2, line: 1)]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .usageLimit)
    }

    @Test func theLimitIsFoundWhateverOrderTheRowsArrivedIn() throws {
        let rows = [closing(3), try claudeLimit(2, line: 0), owner(1)]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .usageLimit)
    }

    @Test func aLimitAfterACrewMessageIsTheLimit() throws {
        let crew = try CrewMessage(event: .said, sender: .subagent, from: "worker", text: "done", sent: "done").payload()
        let rows = [
            Message(sessionID: chat, seq: 1, kind: .crew, payload: crew),
            try claudeLimit(2, line: 0), closing(3),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .usageLimit)
    }

    @Test func aCrewMessageAfterALimitOpensANewTurn() throws {
        let crew = try CrewMessage(event: .said, sender: .subagent, from: "worker", text: "done", sent: "done").payload()
        let rows = [
            owner(0), try claudeLimit(1, line: 0), closing(2),
            Message(sessionID: chat, seq: 3, kind: .crew, payload: crew),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func ownerStopIsNotTheLimit() {
        let rows = [
            owner(1),
            reply(2, "Working on it"),
            row(3, .result, #"{"type":"result","subtype":"error_during_execution","is_error":true,"stop_reason":"interrupted"}"#),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func unknownFailureIsNotTheLimit() {
        let rows = [
            owner(1),
            row(2, .assistantText, #"{"type":"assistant","message":{"model":"<synthetic>","content":[{"type":"text","text":"API Error: 529 overloaded"}]},"error":"unknown","is_api_error_message":true,"api_error_status":529}"#),
            row(3, .error, #"{"message":"the process exited"}"#),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func aRateLimitThatIsNotAUsageLimitIsNotTheLimit() {
        let rows = [
            owner(1),
            row(2, .assistantText, #"{"type":"assistant","message":{"model":"<synthetic>","content":[{"type":"text","text":"Request rejected (429) · slow down"}]},"error":"rate_limit","is_api_error_message":true,"api_error_status":429}"#),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func aLimitInAnOlderTurnDoesNotCount() throws {
        let rows = [
            owner(1), try claudeLimit(2, line: 0), closing(3),
            owner(4, "try again"), reply(5, "Done"),
            row(6, .result, #"{"type":"result","subtype":"success","is_error":false}"#),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func aLimitFollowedByRealWorkInTheSameTurnDoesNotCount() throws {
        let rows = [owner(1), try claudeLimit(2, line: 0), reply(3, "Back again, finished")]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func anAssistantReplyAboutRateLimitsIsNotTheLimit() {
        let rows = [
            owner(1, "how do we handle 429s?"),
            reply(2, "You've hit your session limit is what the CLI prints when error is rate_limit with status 429"),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func aToolResultMentioningRateLimitIsNotTheLimit() {
        let rows = [
            owner(1),
            row(2, .toolResult, #"{"type":"user","message":{"content":[{"type":"tool_result","content":"{\"error\":\"rate_limit\",\"is_api_error_message\":true,\"api_error_status\":429,\"text\":\"You've hit your session limit\"}"}]}}"#),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func claudeShapedRowsOnAnotherProviderAreNotTheLimit() throws {
        let rows = [owner(1), try claudeLimit(2, line: 0)]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .codex) == .other)
    }

    @Test func grokIsNeverTheLimitYet() throws {
        let rows = [owner(1), try claudeLimit(2, line: 0), closing(3)]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .grok) == .other)
    }

    private func limitLine(model: String = "<synthetic>", error: String = "rate_limit", api: Bool = true, status: Int = 429) -> Message {
        row(2, .assistantText, #"{"type":"assistant","message":{"model":"\#(model)","content":[{"type":"text","text":"You've hit your session limit"}]},"error":"\#(error)","is_api_error_message":\#(api),"api_error_status":\#(status)}"#)
    }

    @Test func aRealModelQuotingTheStopIsNotTheLimit() {
        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), limitLine(model: "claude-opus-5")], agent: .claudeCode) == .other)
    }

    @Test func aLineNotMarkedAsAnApiErrorIsNotTheLimit() {
        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), limitLine(api: false)], agent: .claudeCode) == .other)
    }

    @Test func aRateLimitWithAnotherStatusIsNotTheLimit() {
        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), limitLine(status: 503)], agent: .claudeCode) == .other)
    }

    @Test func theSyntheticLineBuiltHereIsTheLimit() {
        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), limitLine()], agent: .claudeCode) == .usageLimit)
    }

    private func capturedDeathLine() throws -> String {
        try fixtureLines("claude-turn-died-mid-response.ndjson")[8]
    }

    @Test func theCapturedStreamLineIsASyntheticErrorThatNoModelWrote() throws {
        let line = try #require(JSONValue.parse(try capturedDeathLine()))

        #expect(TurnStopCause.noModelWrote(line))
        #expect(line["is_api_error_message"]?.boolValue == true)
    }

    @Test func theCapturedStreamFlagIsReadWithoutTheSyntheticModel() throws {
        let written = try capturedDeathLine().replacingOccurrences(of: "<synthetic>", with: "claude-opus-5")
        let line = try #require(JSONValue.parse(written))

        #expect(TurnStopCause.noModelWrote(line))
    }

    @Test func theCapturedServerErrorIsNotTheLimit() throws {
        let rows = [owner(1), row(2, .assistantText, try capturedDeathLine())]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func aStatusOnTheCapturedLineIsReadUnderItsStreamName() throws {
        let written = try capturedDeathLine()
            .replacingOccurrences(of: "\"error\":\"server_error\"", with: "\"error\":\"rate_limit\",\"api_error_status\":429")
            .replacingOccurrences(of: "API Error: Connection lost mid-response. The response above may be incomplete.", with: "You've hit your session limit")

        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), row(2, .assistantText, written)], agent: .claudeCode) == .usageLimit)
    }

    private func typedLine(text: String, error: String = "rate_limit", apiError: String?) -> Message {
        let field = apiError.map { #","api_error":"\#($0)""# } ?? ""
        return row(2, .assistantText, #"{"type":"assistant","message":{"model":"<synthetic>","content":[{"type":"text","text":"\#(text)"}]},"error":"\#(error)"\#(field)}"#)
    }

    @Test func theTypedFieldNamesALimitWhateverItsWordsSay() {
        for words in ["You've reached your Fable limit", "You're out of usage credits", "Words nobody has measured"] {
            let line = typedLine(text: words, apiError: "usage_limit_reached")
            #expect(TurnStopCause.ofLastTurn(messages: [owner(1), line], agent: .claudeCode) == .usageLimit)
        }
    }

    @Test func anotherValueOfTheTypedFieldIsNotTheLimitEvenWithTheMeasuredWords() {
        let line = typedLine(text: "You've hit your session limit", apiError: "model_requires_usage_credits")
        let flagged = row(2, .assistantText, #"{"type":"assistant","message":{"model":"<synthetic>","content":[{"type":"text","text":"You've hit your session limit"}]},"error":"rate_limit","is_api_error_message":true,"api_error_status":429,"api_error":"field_not_granted"}"#)

        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), line], agent: .claudeCode) == .other)
        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), flagged], agent: .claudeCode) == .other)
    }

    @Test func aRateLimitWithNeitherTheFieldNorTheMeasuredWordsIsNotTheLimit() {
        let line = typedLine(text: "You've reached your Fable limit", apiError: nil)

        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), line], agent: .claudeCode) == .other)
    }

    @Test func theTypedFieldNeedsTheRateLimitErrorAndTheSyntheticModel() {
        let otherError = typedLine(text: "You've hit your session limit", error: "server_error", apiError: "usage_limit_reached")
        let realModel = row(2, .assistantText, #"{"type":"assistant","message":{"model":"claude-opus-5","content":[{"type":"text","text":"x"}]},"error":"rate_limit","api_error":"usage_limit_reached"}"#)

        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), otherError], agent: .claudeCode) == .other)
        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), realModel], agent: .claudeCode) == .other)
    }

    @Test func theFixtureLineWithTheFieldIsReadThroughIt() throws {
        let written = try fixtureLines("claude-usage-limit.ndjson")[1]
            .replacingOccurrences(of: "You've hit your session limit", with: "Words nobody has measured")

        #expect(TurnStopCause.ofLastTurn(messages: [owner(1), row(2, .assistantText, written)], agent: .claudeCode) == .usageLimit)
    }

    @Test func noRowsIsNotTheLimit() {
        #expect(TurnStopCause.ofLastTurn(messages: [], agent: .claudeCode) == .other)
    }

    private func mark(_ seq: Int, _ mark: HandoffMark) -> Message {
        row(seq, .handoff, String(decoding: mark.payload, as: UTF8.self))
    }

    private func moved(_ seq: Int, to agent: AgentKind, from: AgentKind) -> Message {
        mark(seq, .continued(agent: agent, model: "m", from: from))
    }

    @Test func aLimitAlreadyResumedIsNotTheCauseOfTheNextSwitch() throws {
        let rows = [
            owner(1), try claudeLimit(2, line: 0), closing(3),
            moved(4, to: .claudeCode, from: .claudeCode), mark(5, .resuming),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func claudeBackAfterACodexStopDoesNotReadTheOldLimitAgain() throws {
        let rows = [
            owner(1), try claudeLimit(2, line: 0), closing(3),
            moved(4, to: .codex, from: .claudeCode), mark(5, .resuming),
            moved(6, to: .claudeCode, from: .codex),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .other)
    }

    @Test func aNewLimitAfterAResumeIsANewCut() throws {
        let rows = [
            owner(1), try claudeLimit(2, line: 0), closing(3), mark(4, .resuming), try claudeLimit(5, line: 0),
        ]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .usageLimit)
    }

    @Test func aSwitchThatResumedNothingStillLeavesTheLimitStanding() throws {
        let rows = [owner(1), try claudeLimit(2, line: 0), closing(3), moved(4, to: .codex, from: .claudeCode)]

        #expect(TurnStopCause.ofLastTurn(messages: rows, agent: .claudeCode) == .usageLimit)
    }
}
