import Testing
@testable import Core

@Suite struct TerminalActivityScheduleTests {
    @Test func theForegroundTickStaysAtTwoSeconds() {
        #expect(TerminalActivitySchedule.tick(isAppActive: true) == .seconds(2))
    }

    @Test func theBackgroundTickIsNoShorterThanTenSeconds() {
        #expect(TerminalActivitySchedule.tick(isAppActive: false) >= .seconds(10))
        #expect(TerminalActivitySchedule.runScriptTick(isAppActive: false) >= .seconds(10))
    }

    @Test func aRunScriptIsWatchedEverySecondInFront() {
        #expect(TerminalActivitySchedule.runScriptTick(isAppActive: true) == .seconds(1))
    }

    @Test func aSharedReadingLivesNoLongerThanTheForegroundTick() {
        #expect(TerminalActivitySchedule.readingMaxAge <= TerminalActivitySchedule.foregroundTick)
        #expect(TerminalActivitySchedule.readingMaxAge > TerminalActivitySchedule.runScriptForegroundTick)
    }

    @Test func commandsAreRecordedEveryThirtySeconds() {
        let start = ContinuousClock.now
        #expect(!TerminalActivitySchedule.isRecordDue(lastRecorded: start, now: start + .seconds(29)))
        #expect(TerminalActivitySchedule.isRecordDue(lastRecorded: start, now: start + .seconds(30)))
    }
}
