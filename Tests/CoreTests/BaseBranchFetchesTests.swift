import Foundation
import Testing
@testable import Core

@Suite("Base branch fetches", .timeLimit(.minutes(1)))
struct BaseBranchFetchesTests {
    private actor Gate {
        private(set) var calls = 0
        private var isOpen = false
        private var held: [CheckedContinuation<Void, Never>] = []
        private var arrival: CheckedContinuation<Void, Never>?

        func arrive() async {
            calls += 1
            arrival?.resume()
            arrival = nil
            guard !isOpen else { return }
            await withCheckedContinuation { held.append($0) }
        }

        func waitForFirstArrival() async {
            guard calls == 0 else { return }
            await withCheckedContinuation { arrival = $0 }
        }

        func open() {
            isOpen = true
            for continuation in held { continuation.resume() }
            held = []
        }
    }

    private final class ManualClock: @unchecked Sendable {
        private let lock = NSLock()
        private var current = ContinuousClock.now

        var now: ContinuousClock.Instant { lock.withLock { current } }

        func advance(by duration: Duration) {
            lock.withLock { current += duration }
        }
    }

    private actor Counter {
        private(set) var calls = 0

        func count() {
            calls += 1
        }
    }

    @Test("a fetch already running is joined rather than started twice")
    func joinsTheRunningFetch() async {
        let gate = Gate()
        let fetches = BaseBranchFetches { _, _, _ in
            await gate.arrive()
            return true
        }

        async let first = fetches.refresh("main", in: "/repo", remote: "origin")
        await gate.waitForFirstArrival()
        async let second = fetches.refresh("main", in: "/repo", remote: "origin")
        while await fetches.joined < 1 { await Task.yield() }
        await gate.open()

        let answers = await [first, second]
        #expect(answers == [true, true])
        #expect(await gate.calls == 1)
        #expect(await fetches.flights == 0)
    }

    @Test("a recent success is trusted, an old one is not, and no age always fetches")
    func trustsOnlyARecentSuccess() async {
        let counter = Counter()
        let clock = ManualClock()
        let fetches = BaseBranchFetches(
            fetch: { _, _, _ in
                await counter.count()
                return true
            },
            now: { clock.now }
        )

        _ = await fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        _ = await fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        #expect(await counter.calls == 1)

        _ = await fetches.refresh("main", in: "/repo", remote: "origin")
        #expect(await counter.calls == 2)

        clock.advance(by: .seconds(121))
        _ = await fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        #expect(await counter.calls == 3)
    }

    @Test("a failed fetch is never remembered")
    func failureIsNotRemembered() async {
        let counter = Counter()
        let fetches = BaseBranchFetches { _, _, _ in
            await counter.count()
            return false
        }

        let first = await fetches.refresh(
            "main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120)
        )
        let second = await fetches.refresh(
            "main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120)
        )
        #expect(first == false)
        #expect(second == false)
        #expect(await counter.calls == 2)
    }

    @Test("another branch, directory or remote is another fetch")
    func keyedOnBranchDirectoryAndRemote() async {
        let counter = Counter()
        let fetches = BaseBranchFetches { _, _, _ in
            await counter.count()
            return true
        }

        _ = await fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        _ = await fetches.refresh("develop", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        _ = await fetches.refresh("main", in: "/other", remote: "origin", acceptingWithin: .seconds(120))
        _ = await fetches.refresh("main", in: "/repo", remote: "upstream", acceptingWithin: .seconds(120))
        #expect(await counter.calls == 4)
    }

    private actor Recorder {
        private(set) var arguments: [String] = []

        func record(_ values: [String]) {
            arguments = values
        }
    }

    @Test("the arguments reach the fetch in the order they were given")
    func passesBranchDirectoryAndRemote() async {
        let recorder = Recorder()
        let fetches = BaseBranchFetches { branch, directory, remote in
            await recorder.record([branch ?? "*", directory, remote])
            return true
        }

        _ = await fetches.refresh("develop", in: "/repo", remote: "upstream")
        #expect(await recorder.arguments == ["develop", "/repo", "upstream"])
    }

    @Test("the window a caller is asked to trust is two minutes")
    func trustWindowIsTwoMinutes() {
        #expect(BaseBranchFetches.recent == .seconds(120))
    }

    @Test("a fetch of every branch asks for no branch in particular")
    func everyBranchPassesNoBranch() async {
        let recorder = Recorder()
        let fetches = BaseBranchFetches { branch, directory, remote in
            await recorder.record([branch ?? "*", directory, remote])
            return true
        }

        _ = await fetches.refreshBranches(in: "/repo", remote: "origin")
        #expect(await recorder.arguments == ["*", "/repo", "origin"])
    }

    @Test("a recent fetch of every branch is trusted for any one branch, but only when an age is given")
    func everyBranchCoversOneBranch() async {
        let counter = Counter()
        let fetches = BaseBranchFetches { _, _, _ in
            await counter.count()
            return true
        }

        _ = await fetches.refreshBranches(in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        _ = await fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        #expect(await counter.calls == 1)

        _ = await fetches.refresh("main", in: "/repo", remote: "origin")
        #expect(await counter.calls == 2)

        _ = await fetches.refresh("main", in: "/repo", remote: "upstream", acceptingWithin: .seconds(120))
        #expect(await counter.calls == 3)
    }

    @Test("a branch asked for while every branch is being fetched joins that fetch")
    func oneBranchJoinsEveryBranch() async {
        let gate = Gate()
        let fetches = BaseBranchFetches { _, _, _ in
            await gate.arrive()
            return true
        }

        async let everything = fetches.refreshBranches(in: "/repo", remote: "origin")
        await gate.waitForFirstArrival()
        async let one = fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        while await fetches.joined < 1 { await Task.yield() }
        await gate.open()

        let answers = await [everything, one]
        #expect(answers == [true, true])
        #expect(await gate.calls == 1)
    }

    @Test("a single branch fetch never stands in for every branch")
    func oneBranchDoesNotCoverEveryBranch() async {
        let counter = Counter()
        let fetches = BaseBranchFetches { _, _, _ in
            await counter.count()
            return true
        }

        _ = await fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        _ = await fetches.refreshBranches(in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        #expect(await counter.calls == 2)
    }
    @Test("a fetch nobody waits for any more is stopped rather than left to time out")
    func abandonedFetchStops() async {
        let fetches = BaseBranchFetches { _, _, _ in
            try? await Task.sleep(for: .seconds(30))
            return !Task.isCancelled
        }

        let waiter = Task { await fetches.refresh("main", in: "/repo", remote: "origin") }
        await waitUntil("the fetch has started") { await fetches.flights == 1 }
        waiter.cancel()

        await waitUntil("the abandoned fetch has ended", within: .seconds(3)) { await fetches.flights == 0 }
        #expect(await waiter.value == false)
    }

    @Test("a fetch someone else still waits for keeps running when one waiter leaves")
    func sharedFetchSurvivesOneLeaving() async {
        let gate = Gate()
        let fetches = BaseBranchFetches { _, _, _ in
            await gate.arrive()
            return !Task.isCancelled
        }

        let leaving = Task { await fetches.refresh("main", in: "/repo", remote: "origin") }
        await gate.waitForFirstArrival()
        async let staying = fetches.refresh("main", in: "/repo", remote: "origin")
        while await fetches.joined < 1 { await Task.yield() }
        await waitUntil("both are waiting") { await fetches.waiting == 2 }
        leaving.cancel()
        await waitUntil("the one leaving has left") { await fetches.waiting == 1 }
        await gate.open()

        #expect(await staying == true)
        #expect(await gate.calls == 1)
    }

    @Test("no more than two prefetches run at once, and the third is not started")
    func prefetchesHaveACeiling() async {
        let gate = Gate()
        let fetches = BaseBranchFetches { _, _, _ in
            await gate.arrive()
            return true
        }

        async let first = fetches.prefetch("main", in: "/repo", remote: "origin")
        async let second = fetches.prefetch("develop", in: "/repo", remote: "origin")
        await waitUntil("both prefetches have started") { await fetches.prefetchFlights == 2 }
        let third = await fetches.prefetch("release", in: "/repo", remote: "origin")
        await gate.open()

        #expect(third == false)
        #expect(await [first, second] == [true, true])
        #expect(await gate.calls == 2)
        #expect(await fetches.prefetchFlights == 0)
        #expect(BaseBranchFetches.prefetchCeiling == 2)
    }

    @Test("the ceiling is for prefetches only, a cut always fetches its base")
    func refreshIgnoresTheCeiling() async {
        let gate = Gate()
        let fetches = BaseBranchFetches { _, _, _ in
            await gate.arrive()
            return true
        }

        async let first = fetches.prefetch("main", in: "/repo", remote: "origin")
        async let second = fetches.prefetch("develop", in: "/repo", remote: "origin")
        await waitUntil("both prefetches have started") { await fetches.prefetchFlights == 2 }
        async let cut = fetches.refresh("release", in: "/repo", remote: "origin")
        await waitUntil("the cut's fetch has started") { await gate.calls == 3 }
        await gate.open()

        #expect(await [first, second, cut] == [true, true, true])
    }
}
