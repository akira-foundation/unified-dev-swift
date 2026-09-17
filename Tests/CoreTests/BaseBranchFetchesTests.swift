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
            await recorder.record([branch, directory, remote])
            return true
        }

        _ = await fetches.refresh("develop", in: "/repo", remote: "upstream")
        #expect(await recorder.arguments == ["develop", "/repo", "upstream"])
    }
}
