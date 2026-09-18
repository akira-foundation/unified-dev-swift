import Testing
@testable import Core

@Suite("Whether an editor update would overwrite what was just typed")
struct EditorEchoTests {
    @Test("a stale value arriving after typing would discard it")
    func staleValueDiscardsTyping() {
        #expect(EditorEcho.wouldDiscardTyping(published: "ab", shown: "ab", incoming: "a"))
    }

    @Test("the value just typed arriving back is not a discard")
    func echoOfTypingIsNotADiscard() {
        #expect(!EditorEcho.wouldDiscardTyping(published: "ab", shown: "ab", incoming: "ab"))
    }

    @Test("before anything is typed, an incoming value is always taken")
    func nothingTypedYet() {
        #expect(!EditorEcho.wouldDiscardTyping(published: nil, shown: "", incoming: "loaded"))
    }

    @Test("a value set from outside after typing moved on is taken")
    func externalChangeAfterTheViewMovedOn() {
        #expect(!EditorEcho.wouldDiscardTyping(published: "ab", shown: "abc", incoming: "reverted"))
    }
}
