import Foundation
import Testing
@testable import Core

@Suite("Single flight")
struct SingleFlightTests {
    @MainActor
    private final class Runs {
        var started = 0
        var finished = 0
        var rows: [Int] = []
    }

    @MainActor
    @Test("two callers arriving together run the work once between them")
    func coalescesConcurrentCallers() async {
        let flight = SingleFlight()
        let runs = Runs()

        async let first: Void = flight.run { await Self.suspendingWork(runs) }
        async let second: Void = flight.run { await Self.suspendingWork(runs) }
        _ = await (first, second)

        #expect(runs.started == 1)
        #expect(runs.finished == 1)
    }

    @MainActor
    @Test("the caller that waits does not return before the work has finished")
    func theSecondCallerWaitsForTheFirst() async {
        let flight = SingleFlight()
        let runs = Runs()

        async let first: Void = flight.run { await Self.suspendingWork(runs) }
        async let second: Void = flight.run { await Self.suspendingWork(runs) }
        _ = await (first, second)

        #expect(runs.finished == 1)
    }

    @MainActor
    @Test("a run started after the last one finished is a run of its own")
    func runsAgainOnceTheFirstIsOver() async {
        let flight = SingleFlight()
        let runs = Runs()

        await flight.run { await Self.suspendingWork(runs) }
        await flight.run { await Self.suspendingWork(runs) }

        #expect(runs.started == 2)
        #expect(runs.finished == 2)
    }

    @MainActor
    @Test("work that suspends halfway is not left interleaved with a second run of itself")
    func doesNotInterleaveTheHalvesOfTheWork() async {
        let flight = SingleFlight()
        let runs = Runs()

        let rebuild: @Sendable @MainActor () async -> Void = {
            runs.rows = []
            await Task.yield()
            runs.rows.append(contentsOf: [0, 1, 2, 3, 4, 5, 6, 7])
        }

        async let first: Void = flight.run(rebuild)
        async let second: Void = flight.run(rebuild)
        _ = await (first, second)

        #expect(runs.rows == [0, 1, 2, 3, 4, 5, 6, 7])
        #expect(Set(runs.rows).count == runs.rows.count)
    }

    @MainActor
    @Test("waiting returns at once when nothing is under way")
    func waitingOnNothingReturnsAtOnce() async {
        let flight = SingleFlight()
        await flight.wait()
    }

    @MainActor
    @Test("waiting returns only once the run under way has finished")
    func waitingFollowsTheRunUnderWay() async {
        let flight = SingleFlight()
        let runs = Runs()

        async let running: Void = flight.run { await Self.suspendingWork(runs) }
        async let waiting: Void = flight.wait()
        _ = await (running, waiting)

        #expect(runs.finished == 1)
    }

    @MainActor
    private static func suspendingWork(_ runs: Runs) async {
        runs.started += 1
        await Task.yield()
        runs.finished += 1
    }
}
