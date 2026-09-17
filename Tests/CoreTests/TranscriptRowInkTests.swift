import Testing
import Foundation
@testable import Core

@Suite("Knowing a row draws nothing before it is drawn")
struct TranscriptRowInkTests {
    private func payload(_ text: String) -> Data { Data(text.utf8) }

    @Test("a stream event draws nothing")
    func streamEventIsBlank() {
        let row = payload(#"{"type":"stream_event","event":{"type":"content_block_delta"}}"#)
        #expect(TranscriptRowInk.drawsNothing(kind: .system, payload: row))
    }

    @Test("an init row draws something")
    func initIsNotBlank() {
        let row = payload(#"{"type":"system","subtype":"init","cwd":"/tmp","model":"opus"}"#)
        #expect(!TranscriptRowInk.drawsNothing(kind: .system, payload: row))
    }

    @Test("a system row that is not an init draws nothing, whatever its subtype")
    func otherSubtypesAreBlank() {
        for subtype in ["command", "hook_result", "vcs_status", "code_review", "background"] {
            let row = payload(#"{"type":"system","subtype":"\#(subtype)","x":1}"#)
            #expect(TranscriptRowInk.drawsNothing(kind: .system, payload: row))
        }
    }

    @Test("no other kind is claimed")
    func onlySystemIsAnswered() {
        let blank = payload(#"{"type":"stream_event"}"#)
        for kind in [MessageKind.user, .assistantText, .thinking, .toolUse, .toolResult,
                     .permissionAsk, .result, .error, .notice] {
            #expect(!TranscriptRowInk.drawsNothing(kind: kind, payload: blank))
        }
    }

    @Test("the marker is only read from the front of the payload")
    func onlyTheFrontIsRead() {
        let tail = String(repeating: " ", count: 400) + #""subtype":"init""#
        let row = payload(#"{"type":"stream_event","text":"\#(tail)"}"#)
        #expect(TranscriptRowInk.drawsNothing(kind: .system, payload: row))
    }

    @Test("an empty payload draws nothing")
    func emptyIsBlank() {
        #expect(TranscriptRowInk.drawsNothing(kind: .system, payload: Data()))
    }
}
