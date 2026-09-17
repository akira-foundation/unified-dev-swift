import Foundation
import Testing
@testable import Core

@Suite("Build timestamp")
struct BuildTimestampTests {
    private static let brussels = TimeZone(identifier: "Europe/Brussels")!
    private static let belgium = Locale(identifier: "en_GB")

    private static func moment(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = brussels
        return calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    private static func line(_ date: Date, now: Date) -> String {
        BuildTimestamp.line(date, now: now, locale: belgium, timeZone: brussels)
    }

    @Test("A build from this year is a day, a month and a clock, and nothing else")
    func compactWithinTheYear() {
        #expect(
            Self.line(Self.moment(2026, 8, 23, 14, 32), now: Self.moment(2026, 8, 23, 18, 0))
                == "23 Aug 14:32"
        )
    }

    @Test("A build from another year carries the year, because the day alone would collide")
    func yearAppearsWhenItDiffers() {
        #expect(
            Self.line(Self.moment(2025, 8, 23, 14, 32), now: Self.moment(2026, 8, 23, 18, 0))
                == "23 Aug 2025 14:32"
        )
    }

    @Test("No seconds, ever")
    func secondsAreNotShown() {
        let line = Self.line(Self.moment(2026, 1, 2, 9, 5), now: Self.moment(2026, 1, 2, 9, 6))

        #expect(line == "2 Jan 09:05")
        #expect(line.filter { $0 == ":" }.count == 1)
    }

    @Test("The reader's locale decides the order and the clock")
    func localeDecidesTheShape() {
        let built = Self.moment(2026, 8, 23, 14, 32)
        let now = Self.moment(2026, 8, 23, 18, 0)

        let american = BuildTimestamp.line(
            built, now: now, locale: Locale(identifier: "en_US"), timeZone: Self.brussels
        ).map { $0.isWhitespace ? " " : $0 }

        #expect(String(american) == "Aug 23 2:32 PM")
        #expect(
            BuildTimestamp.line(
                built, now: now, locale: Locale(identifier: "nl_BE"), timeZone: Self.brussels
            ) == "23 aug 14:32"
        )
    }

    @Test("The stamp is stored in UTC and read in the reader's own zone")
    func stampIsUTCAndDisplayedLocally() {
        let parsed = BuildTimestamp.parse("2026-08-23T12:32:00Z")

        #expect(parsed == Self.moment(2026, 8, 23, 14, 32))
        #expect(Self.line(parsed!, now: Self.moment(2026, 8, 23, 18, 0)) == "23 Aug 14:32")
    }

    @Test("Absent, blank and malformed stamps are all absent")
    func unusableStampsAreNil() {
        #expect(BuildTimestamp.parse(nil) == nil)
        #expect(BuildTimestamp.parse("   ") == nil)
        #expect(BuildTimestamp.parse("last Tuesday") == nil)
    }

    @Test("A stamped bundle never falls back to the file date")
    func stampOutranksTheFileDate() {
        let stamped = BuildTimestamp.read(
            stamp: "2026-08-23T12:32:00Z", executableModified: Self.moment(2026, 8, 24, 9, 0)
        )

        #expect(stamped == Self.moment(2026, 8, 23, 14, 32))
    }

    @Test("A bundle built before the key existed falls back to the executable's date")
    func fileDateCoversOlderBundles() {
        let mtime = Self.moment(2026, 8, 20, 10, 15)

        #expect(BuildTimestamp.read(stamp: nil, executableModified: mtime) == mtime)
        #expect(BuildTimestamp.read(stamp: "  ", executableModified: mtime) == mtime)
        #expect(BuildTimestamp.read(stamp: "not a date", executableModified: mtime) == mtime)
        #expect(BuildTimestamp.read(stamp: nil, executableModified: nil) == nil)
    }
}
