import Testing
import Foundation
@testable import Core

@Suite("Handoff turn acknowledgement")
struct HandoffTurnAcknowledgementTests {
    private var modelText: AgentEvent {
        .assistantText(AgentTextBlock(text: "working", model: "opus"))
    }

    private var toolCall: AgentEvent {
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls"}}]}}"#
        return AgentEvent.decode(line: line) ?? .unknown(Data())
    }

    private func limitLine() throws -> AgentEvent {
        try #require(AgentEvent.decode(line: try fixtureLines("claude-usage-limit.ndjson")[0]))
    }

    private func carrying() -> HandoffAcknowledgement {
        var state = HandoffAcknowledgement()
        state.promptSent(asSteer: false, carriedDelta: true)
        return state
    }

    @Test("a steer does not acknowledge")
    func steerDoesNotAcknowledge() {
        #expect(HandoffAcknowledgement.applies(toSteer: true) == false)
        #expect(HandoffAcknowledgement.applies(toSteer: false))

        var waiting = HandoffAcknowledgement()
        waiting.promptSent(asSteer: true, carriedDelta: true)
        let confirmed = waiting.replyArrived(modelText)
        #expect(!confirmed)
    }

    @Test("the first real reply confirms once")
    func firstReplyConfirmsOnce() {
        var state = carrying()

        let first = state.replyArrived(modelText)
        let second = state.replyArrived(modelText)

        #expect(first)
        #expect(!second)
    }

    @Test("a tool call is a real reply, and a turn it ended confirms even when interrupted")
    func toolCallThenInterruptedConfirms() {
        var state = carrying()

        let onCall = state.replyArrived(toolCall)
        let onEnd = state.turnEnded()

        #expect(onCall)
        #expect(onEnd)
    }

    @Test("a turn that ends with no reply confirms nothing, however it ended")
    func aSilentTurnConfirmsNothing() {
        var state = carrying()

        let confirmed = state.turnEnded()

        #expect(!confirmed)
        #expect(!state.owedBeforeNextTurn)
    }

    @Test("two terminals in a row confirm nothing")
    func twoTerminalsConfirmNothing() {
        var state = carrying()

        let first = state.turnEnded()
        let second = state.turnEnded()

        #expect(!first)
        #expect(!second)
    }

    @Test("a terminal in a new runner confirms nothing")
    func aNewRunnerConfirmsNothing() {
        var state = HandoffAcknowledgement()

        let confirmed = state.turnEnded()

        #expect(!confirmed)
    }

    @Test("a second terminal after a settled turn confirms nothing more")
    func aTerminalInIdleConfirmsNothing() {
        var state = carrying()
        _ = state.replyArrived(modelText)
        let first = state.turnEnded()

        let second = state.turnEnded()

        #expect(first)
        #expect(!second)
    }

    @Test("a synthetic line is not a reply, so the terminal after it confirms nothing")
    func syntheticLineThenTerminal() throws {
        var state = carrying()

        let onLine = state.replyArrived(try limitLine())
        let onEnd = state.turnEnded()

        #expect(!onLine)
        #expect(!onEnd)
    }

    @Test("an API error line from a named model is not a reply")
    func apiErrorLineIsNotAReply() throws {
        let line = #"{"type":"assistant","isApiErrorMessage":true,"message":{"model":"opus","content":[{"type":"text","text":"API Error: 500"}]}}"#

        #expect(!HandoffAcknowledgement.isRealReply(try #require(AgentEvent.decode(line: line))))
    }

    @Test("a synthetic line with no error flag is not a reply")
    func syntheticModelIsNotAReply() {
        let line = #"{"type":"assistant","message":{"model":"<synthetic>","content":[{"type":"text","text":"text"}]}}"#
        #expect(!HandoffAcknowledgement.isRealReply(AgentEvent.decode(line: line) ?? .unknown(Data())))
    }

    @Test("thinking and blank text are not a reply")
    func thinkingAndBlankAreNotAReply() {
        #expect(!HandoffAcknowledgement.isRealReply(.thinking(AgentTextBlock(text: "hm", model: "opus"))))
        #expect(!HandoffAcknowledgement.isRealReply(.assistantText(AgentTextBlock(text: "  \n", model: "opus"))))
    }

    @Test("a turn stopped after its reply owes a confirmation before the next one")
    func stoppedAfterAReplyOwesAConfirmation() {
        var state = HandoffAcknowledgement()
        #expect(!state.owedBeforeNextTurn)
        state.promptSent(asSteer: false, carriedDelta: true)
        #expect(!state.owedBeforeNextTurn)
        _ = state.replyArrived(modelText)
        #expect(state.owedBeforeNextTurn)
        _ = state.turnEnded()
        #expect(!state.owedBeforeNextTurn)
    }

    @Test("a prompt that carried nothing has nothing to lose, so its turn end settles")
    func aPromptWithoutADeltaHasNothingOutstanding() {
        var state = HandoffAcknowledgement()
        state.promptSent(asSteer: false, carriedDelta: false)

        let onReply = state.replyArrived(modelText)
        let owed = state.owedBeforeNextTurn
        let onEnd = state.turnEnded()

        #expect(!onReply)
        #expect(owed)
        #expect(onEnd)
    }

    @Test("a new process inherits no delta it was never sent")
    func aNewProcessInheritsNothing() {
        var state = carrying()
        state.processStarted()

        let onReply = state.replyArrived(modelText)

        #expect(!onReply)
    }

    @Test("a new process keeps what the last one owed")
    func aNewProcessKeepsWhatIsOwed() {
        var state = carrying()
        _ = state.replyArrived(modelText)

        state.processStarted()

        #expect(state.owedBeforeNextTurn)
    }

    @Test("a real reply in a turn the runner did not start is settled at its end")
    func aReplyInAnIdleRunnerSettlesAtItsEnd() {
        var state = HandoffAcknowledgement()

        let onReply = state.replyArrived(modelText)
        let onEnd = state.turnEnded()

        #expect(!onReply)
        #expect(onEnd)
    }
}
