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

    @Test func userMessageIsWhatWasTyped() throws {
        let payload = Data(try AgentRunner.encodeTurn("Hi").utf8)
        #expect(MessageCopyText.markdown(kind: .user, payload: payload) == "Hi")
    }

    @Test func toolRowsHaveNothingToCopy() {
        #expect(MessageCopyText.markdown(kind: .toolUse, payload: Data("{}".utf8)) == nil)
    }
}
