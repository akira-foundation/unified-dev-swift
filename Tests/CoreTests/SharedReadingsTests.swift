import Testing
import Foundation
import Synchronization
@testable import Core

private final class Tally: Sendable {
    private let count = Mutex(0)
    var reads: Int { count.withLock { $0 } }
    func read() -> Int { count.withLock { $0 += 1; return $0 } }
}

private final class StoppedClock: Sendable {
    private let instant = Mutex(ContinuousClock.now)
    var now: ContinuousClock.Instant { instant.withLock { $0 } }
    func advance(_ by: Duration) { instant.withLock { $0 += by } }
}

private struct Refused: Error {}

@Suite struct SharedReadingsTests {
    @Test func callersOfOneKeyWithinTheAgeShareOneReading() async throws {
        let tally = Tally()
        let clock = StoppedClock()
        let readings = SharedReadings<String, Int>(now: { clock.now })

        let first = try await readings.value(for: "a", notOlderThan: .seconds(20)) { tally.read() }
        clock.advance(.seconds(19))
        let second = try await readings.value(for: "a", notOlderThan: .seconds(20)) { tally.read() }

        #expect(first == 1)
        #expect(second == 1)
        #expect(tally.reads == 1)
    }

    @Test func eachKeyIsReadOnItsOwn() async throws {
        let tally = Tally()
        let readings = SharedReadings<String, Int>()

        let first = try await readings.value(for: "a", notOlderThan: .seconds(20)) { tally.read() }
        let other = try await readings.value(for: "b", notOlderThan: .seconds(20)) { tally.read() }

        #expect(first == 1)
        #expect(other == 2)
    }

    @Test func aReadingAsOldAsTheAgeIsTakenAgain() async throws {
        let tally = Tally()
        let clock = StoppedClock()
        let readings = SharedReadings<String, Int>(now: { clock.now })

        _ = try await readings.value(for: "a", notOlderThan: .seconds(20)) { tally.read() }
        clock.advance(.seconds(20))
        let again = try await readings.value(for: "a", notOlderThan: .seconds(20)) { tally.read() }

        #expect(again == 2)
    }

    @Test func aZeroAgeAlwaysReadsAfresh() async throws {
        let tally = Tally()
        let readings = SharedReadings<String, Int>()

        _ = try await readings.value(for: "a", notOlderThan: .seconds(60)) { tally.read() }
        let fresh = try await readings.value(for: "a", notOlderThan: .zero) { tally.read() }

        #expect(fresh == 2)
    }

    @Test func callersArrivingDuringAReadWaitForIt() async throws {
        let tally = Tally()
        let readings = SharedReadings<String, Int>()
        let read: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(100))
            return tally.read()
        }

        async let first = readings.value(for: "a", notOlderThan: .seconds(20), read: read)
        async let second = readings.value(for: "a", notOlderThan: .seconds(20), read: read)
        async let third = readings.value(for: "a", notOlderThan: .seconds(20), read: read)
        let values = try await [first, second, third]

        #expect(tally.reads == 1)
        #expect(values == [1, 1, 1])
    }

    @Test func aFailureReachesEveryoneWaitingAndIsNotKept() async throws {
        let tally = Tally()
        let readings = SharedReadings<String, Int>()
        let failing: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(100))
            _ = tally.read()
            throw Refused()
        }

        async let first: Int? = try? readings.value(for: "a", notOlderThan: .seconds(20), read: failing)
        async let second: Int? = try? readings.value(for: "a", notOlderThan: .seconds(20), read: failing)
        let outcomes = await [first, second]
        let next = try await readings.value(for: "a", notOlderThan: .seconds(20)) { tally.read() }

        #expect(outcomes == [nil, nil])
        #expect(next == 2)
    }

    @Test func aFreshCallerDoesNotJoinAReadThatStartedBeforeIt() async throws {
        let tally = Tally()
        let readings = SharedReadings<String, Int>()
        let slow: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(200))
            return tally.read()
        }

        async let older = readings.value(for: "a", notOlderThan: .seconds(20), read: slow)
        try? await Task.sleep(for: .milliseconds(50))
        let fresh = try await readings.value(for: "a", notOlderThan: .zero, read: slow)
        _ = try await older

        #expect(tally.reads == 2)
        #expect(fresh == 2)
    }

    @Test func aReadingCountsFromWhenItWasAskedFor() async throws {
        let tally = Tally()
        let clock = StoppedClock()
        let readings = SharedReadings<String, Int>(now: { clock.now })
        let read: @Sendable () async throws -> Int = {
            clock.advance(.seconds(5))
            return tally.read()
        }

        _ = try await readings.value(for: "a", notOlderThan: .seconds(20), read: read)
        clock.advance(.seconds(14))
        let stillShared = try await readings.value(for: "a", notOlderThan: .seconds(20), read: read)
        clock.advance(.seconds(1))
        let taken = try await readings.value(for: "a", notOlderThan: .seconds(20), read: read)

        #expect(stillShared == 1)
        #expect(taken == 2)
    }

    @Test func readingsOlderThanTheRetentionAreLetGo() async throws {
        let clock = StoppedClock()
        let readings = SharedReadings<String, Int>(retention: .seconds(600), now: { clock.now })

        _ = try await readings.value(for: "gone", notOlderThan: .seconds(20)) { 1 }
        clock.advance(.seconds(600))
        _ = try await readings.value(for: "kept", notOlderThan: .seconds(20)) { 2 }

        #expect(await readings.keptCount == 1)
    }
    @Test func aCallerJoinsAReadInFlightOnlyWhileItIsYoungerThanItsAge() async throws {
        let tally = Tally()
        let clock = StoppedClock()
        let readings = SharedReadings<String, Int>(now: { clock.now })
        let slow: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(200))
            return tally.read()
        }

        async let first = readings.value(for: "a", notOlderThan: .seconds(20), read: slow)
        try? await Task.sleep(for: .milliseconds(50))
        clock.advance(.seconds(20))
        let late = try await readings.value(for: "a", notOlderThan: .seconds(20), read: slow)
        _ = try await first

        #expect(tally.reads == 2)
        #expect(late == 2)
    }

    @Test func anOlderReadFinishingLastNeitherReplacesTheNewerAnswerNorItsRead() async throws {
        let tally = Tally()
        let clock = StoppedClock()
        let readings = SharedReadings<String, Int>(now: { clock.now })
        let slowest: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(400))
            return 100 + tally.read()
        }
        let slow: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(200))
            return tally.read()
        }

        async let older = readings.value(for: "a", notOlderThan: .seconds(20), read: slowest)
        try? await Task.sleep(for: .milliseconds(50))
        clock.advance(.seconds(1))
        async let newer = readings.value(for: "a", notOlderThan: .zero, read: slow)
        _ = try await [older, newer]
        clock.advance(.seconds(1))
        let kept = try await readings.value(for: "a", notOlderThan: .seconds(20)) { tally.read() }

        #expect(kept == 1)
        #expect(tally.reads == 2)
    }

    @Test func aFinishedOlderReadLeavesTheNewerReadInFlightToJoin() async throws {
        let tally = Tally()
        let clock = StoppedClock()
        let readings = SharedReadings<String, Int>(now: { clock.now })
        let quick: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(100))
            return tally.read()
        }
        let slow: @Sendable () async throws -> Int = {
            try? await Task.sleep(for: .milliseconds(400))
            return tally.read()
        }

        async let older = readings.value(for: "a", notOlderThan: .seconds(20), read: quick)
        try? await Task.sleep(for: .milliseconds(20))
        clock.advance(.seconds(10))
        async let newer = readings.value(for: "a", notOlderThan: .zero, read: slow)
        _ = try await older
        clock.advance(.seconds(15))
        let joined = try await readings.value(for: "a", notOlderThan: .seconds(20), read: quick)
        _ = try await newer

        #expect(tally.reads == 2)
        #expect(joined == 2)
    }
}
