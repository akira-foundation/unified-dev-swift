import Testing
@testable import Core

struct TranscriptRowShapeTests {
    @Test("a request and an answer are not the same shape")
    func splitsWhatIsWrittenFromWhatComesBack() {
        #expect(TranscriptRowShape.of(kind: .user) == .message)
        #expect(TranscriptRowShape.of(kind: .crew) == .message)
        #expect(TranscriptRowShape.of(kind: .assistantText) == .answer)
        #expect(TranscriptRowShape.of(kind: .thinking) == .answer)
    }

    @Test("a call and its result are one shape")
    func groupsTheWorking() {
        #expect(TranscriptRowShape.of(kind: .toolUse) == .tool)
        #expect(TranscriptRowShape.of(kind: .toolResult) == .tool)
        #expect(TranscriptRowShape.of(kind: .permissionAsk) == .tool)
    }

    @Test("a turn's footer is its own shape, because it is the same rule every time")
    func footerIsItsOwn() {
        #expect(TranscriptRowShape.of(kind: .result) == .footer)
    }

    @Test("what the app says about itself is one shape")
    func groupsTheNotices() {
        #expect(TranscriptRowShape.of(kind: .error) == .notice)
        #expect(TranscriptRowShape.of(kind: .notice) == .notice)
        #expect(TranscriptRowShape.of(kind: .system) == .notice)
    }

    @Test("every stored kind belongs somewhere")
    func nothingFallsThrough() {
        for kind in MessageKind.allCases {
            #expect(TranscriptRowShape.of(kind: kind) != .other)
        }
    }
}
