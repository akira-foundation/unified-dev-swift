import Testing
import Foundation
@testable import Core

@Suite("Transcript timestamp")
struct TranscriptTimestampTests {
    @Test("a stamp in UTC is the instant it names")
    func utc() throws {
        let read = try #require(TranscriptTimestamp.date(from: "2026-10-11T09:00:00.000Z"))
        #expect(read.timeIntervalSince1970 == 1_791_709_200)
    }

    @Test("the fraction of a second is kept")
    func fraction() throws {
        let read = try #require(TranscriptTimestamp.date(from: "2026-10-11T09:00:00.250Z"))
        #expect(read.timeIntervalSince1970 == 1_791_709_200.25)
    }

    @Test("a stamp with no fraction reads the same second")
    func withoutFraction() throws {
        let read = try #require(TranscriptTimestamp.date(from: "2026-10-11T09:00:00Z"))
        #expect(read.timeIntervalSince1970 == 1_791_709_200)
    }

    @Test("an offset ahead of UTC names an earlier instant")
    func positiveOffset() throws {
        let read = try #require(TranscriptTimestamp.date(from: "2026-10-11T11:00:00.000+02:00"))
        #expect(read.timeIntervalSince1970 == 1_791_709_200)
    }

    @Test("an offset behind UTC names a later instant")
    func negativeOffset() throws {
        let read = try #require(TranscriptTimestamp.date(from: "2026-10-11T04:00:00.000-05:00"))
        #expect(read.timeIntervalSince1970 == 1_791_709_200)
    }

    @Test("an offset written without a colon reads its minutes")
    func offsetWithoutAColon() throws {
        let read = try #require(TranscriptTimestamp.date(from: "2026-10-11T14:30:00.000+0530"))
        #expect(read.timeIntervalSince1970 == 1_791_709_200)
    }

    @Test("a leap day is the day it says it is")
    func leapDay() {
        #expect(TranscriptTimestamp.daysFromCivil(year: 2024, month: 2, day: 29) == 19_782)
        #expect(TranscriptTimestamp.daysFromCivil(year: 1970, month: 1, day: 1) == 0)
    }

    @Test("something that is not a stamp is not a date")
    func rubbish() {
        #expect(TranscriptTimestamp.date(from: "") == nil)
        #expect(TranscriptTimestamp.date(from: "the ninth of May") == nil)
        #expect(TranscriptTimestamp.date(from: "2026-13-11T09:00:00Z") == nil)
        #expect(TranscriptTimestamp.date(from: "2026-10-99T09:00:00Z") == nil)
    }
}
