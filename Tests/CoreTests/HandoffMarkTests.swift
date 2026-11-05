import Testing
import Foundation
@testable import Core

@Suite("Handoff mark")
struct HandoffMarkTests {
    @Test("a continued mark names the agent and the model")
    func continuedSentence() {
        #expect(HandoffMark.continued(agent: .codex, model: "GPT-5.6").sentence == "Continued with Codex · GPT-5.6")
    }

    @Test("a resuming mark says the task was interrupted")
    func resumingSentence() {
        #expect(HandoffMark.resuming.sentence == "Resuming the interrupted task")
    }

    @Test("a mark survives encoding")
    func roundTrips() throws {
        let mark = HandoffMark.continued(agent: .claudeCode, model: "Opus")
        let data = try JSONEncoder().encode(mark)
        #expect(try JSONDecoder().decode(HandoffMark.self, from: data) == mark)
    }

    @Test("a divider adds nothing to a side conversation's context")
    func sideConversationIgnoresDividers() {
        let session = SessionID("s")
        let divider = Message(sessionID: session, seq: 1, kind: .handoff, payload: HandoffMark.resuming.payload)
        let text = Message(sessionID: session, seq: 0, kind: .assistantText, payload: Data())

        #expect(SideConversation.context(messages: [divider]) == "")
        #expect(SideConversation.context(messages: [text, divider]) == SideConversation.context(messages: [text]))
    }
}
