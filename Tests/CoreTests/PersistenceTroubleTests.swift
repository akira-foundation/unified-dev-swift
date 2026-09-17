import Foundation
import Testing
@testable import Core

@Suite("Persistence trouble")
struct PersistenceTroubleTests {
    private static func complaint(_ standing: TranscriptStanding) -> WorkspaceTrouble? {
        WorkspaceTrouble.recording(transcript: standing, complaint: "FOREIGN KEY constraint failed")
    }

    @Test("a refusal from a session that is still there is reported and counted")
    func reportsARealFailure() {
        var trouble = PersistenceTrouble()

        let outcome = trouble.record(Self.complaint(.there))

        guard case .tell(let sentence) = outcome else {
            Issue.record("a live transcript's refusal has to be told: \(outcome)")
            return
        }
        #expect(sentence.contains("FOREIGN KEY constraint failed"))
        #expect(trouble.failures == 1)
        #expect(trouble.lastSentence == sentence)
        #expect(!trouble.hasStopped)
    }

    @Test("a store that cannot say whether the transcript is there still reports")
    func reportsAnUnanswerableStore() {
        var trouble = PersistenceTrouble()

        let outcome = trouble.record(Self.complaint(.unanswerable))

        #expect(outcome != .stop)
        #expect(trouble.failures == 1)
        #expect(!trouble.hasStopped)
    }

    @Test("a transcript that has gone stops the run without a word")
    func stopsWhenTheTranscriptHasGone() {
        var trouble = PersistenceTrouble()

        let outcome = trouble.record(Self.complaint(.gone))

        #expect(outcome == .stop)
        #expect(trouble.hasStopped)
        #expect(trouble.failures == 0)
        #expect(trouble.lastSentence == nil)
    }

    @Test("the second refusal after the transcript went stops nothing")
    func stopsOnlyOnce() {
        var trouble = PersistenceTrouble()

        let first = trouble.record(Self.complaint(.gone))
        let second = trouble.record(Self.complaint(.gone))
        let third = trouble.record(Self.complaint(.gone))

        #expect(first == .stop)
        #expect(second == .alreadyStopped)
        #expect(third == .alreadyStopped)
        #expect(trouble.failures == 0)
    }

    @Test("failures before the transcript went are kept, and the stop does not clear them")
    func keepsWhatWasReportedBeforeTheStop() {
        var trouble = PersistenceTrouble()

        _ = trouble.record(Self.complaint(.there))
        _ = trouble.record(Self.complaint(.there))
        #expect(trouble.failures == 2)

        let stopped = trouble.record(Self.complaint(.gone))

        #expect(stopped == .stop)
        #expect(trouble.failures == 2)
        #expect(trouble.lastSentence != nil)
    }
}
