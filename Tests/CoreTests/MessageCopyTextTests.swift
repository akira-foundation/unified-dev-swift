import Foundation
import Testing
@testable import Core

@Suite("Message copy text")
struct MessageCopyTextTests {
    private func answer(_ text: String) -> Data {
        Data(#"{"type":"assistant","message":{"content":[{"type":"text","text":"\#(text)"}]}}"#.utf8)
    }

    @Test func answerMarkdownIsTheOriginalText() {
        #expect(MessageCopyText.markdown(kind: .assistantText, payload: answer("**Bold** and `code`")) == "**Bold** and `code`")
    }

    @Test func answerPlainDropsTheMarkup() {
        #expect(MessageCopyText.plain(kind: .assistantText, payload: answer("**Bold** and `code`")) == "Bold and code")
    }

    @Test func userPlainTextIsWhatWasTyped() throws {
        let payload = Data(try AgentRunner.encodeTurn("rename snake_case_name to a * b").utf8)
        #expect(MessageCopyText.plain(kind: .user, payload: payload) == "rename snake_case_name to a * b")
    }

    @Test func userMessageIsWhatWasTyped() throws {
        let payload = Data(try AgentRunner.encodeTurn("Hi").utf8)
        #expect(MessageCopyText.markdown(kind: .user, payload: payload) == "Hi")
    }

    @Test func userMessageLeavesInjectedInstructionsOut() throws {
        let payload = Data(try AgentRunner.encodeTurn("Merge #42.\n\n\(MergeInstructions.canonical)").utf8)
        #expect(MessageCopyText.markdown(kind: .user, payload: payload) == "Merge #42.")
    }

    @Test func emptyAnswerHasNothingToCopy() {
        #expect(MessageCopyText.markdown(kind: .assistantText, payload: answer("")) == nil)
    }

    @Test func answerThatIsNotTextHasNothingToCopy() {
        let toolUse = Data(#"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t","name":"Bash","input":{}}]}}"#.utf8)
        #expect(MessageCopyText.markdown(kind: .assistantText, payload: toolUse) == nil)
    }

    @Test(arguments: [MessageKind.toolUse, .toolResult, .thinking, .error, .notice, .system])
    func otherRowsHaveNothingToCopy(kind: MessageKind) {
        #expect(MessageCopyText.markdown(kind: kind, payload: answer("Hidden")) == nil)
    }
}
