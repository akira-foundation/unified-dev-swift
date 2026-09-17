import Foundation
import Testing
@testable import Core

@Suite("The remembered base of a workspace diff")
struct BaselineCacheTests {
    private let head = "1111111111111111111111111111111111111111"
    private let local = "2222222222222222222222222222222222222222"
    private let remote = "3333333333333333333333333333333333333333"

    @Test("the three refs go to rev-parse in a fixed order")
    func asks() {
        #expect(BaselineFingerprint.arguments(base: "main", remote: "origin") == [
            "rev-parse", "--revs-only", "HEAD", "main", "refs/remotes/origin/main",
        ])
    }

    @Test("a ref that moves changes the key")
    func moves() {
        let before = BaselineFingerprint.make("\(head)\n\(local)\n\(remote)\n")
        let after = BaselineFingerprint.make("\(head)\n\(local)\n\(head)\n")

        #expect(before != nil)
        #expect(before != after)
    }

    @Test("a ref that appears changes the key")
    func appears() {
        let withoutRemote = BaselineFingerprint.make("\(head)\n\(local)\n")
        let withRemote = BaselineFingerprint.make("\(head)\n\(local)\n\(remote)\n")

        #expect(withoutRemote != withRemote)
    }

    @Test("trailing whitespace is not a different graph")
    func whitespace() {
        #expect(
            BaselineFingerprint.make("\(head)\n\(local)\n")
                == BaselineFingerprint.make("  \(head)  \n\(local)\n\n")
        )
    }

    @Test("an answer with nothing in it is no key")
    func empty() {
        #expect(BaselineFingerprint.make("") == nil)
        #expect(BaselineFingerprint.make("\n  \n") == nil)
    }

    @Test("an answer comes back only for the key it was stored under")
    func hitAndMiss() async {
        let cache = BaselineCache()
        await cache.remember(worktree: "/w", base: "main", fingerprint: "a", baseline: local)

        #expect(await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") == local)
        #expect(await cache.baseline(worktree: "/w", base: "main", fingerprint: "b") == nil)
        #expect(await cache.baseline(worktree: "/w", base: "trunk", fingerprint: "a") == nil)
        #expect(await cache.baseline(worktree: "/other", base: "main", fingerprint: "a") == nil)
    }

    @Test("a moved ref replaces the entry rather than adding one")
    func replaces() async {
        let cache = BaselineCache()
        await cache.remember(worktree: "/w", base: "main", fingerprint: "a", baseline: local)
        await cache.remember(worktree: "/w", base: "main", fingerprint: "b", baseline: remote)

        #expect(await cache.count == 1)
        #expect(await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") == nil)
        #expect(await cache.baseline(worktree: "/w", base: "main", fingerprint: "b") == remote)
    }

    @Test("callers arriving together resolve once")
    func joinsOneFlight() async throws {
        let cache = BaselineCache()
        let gate = Gate()

        async let first = cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.local
        }
        await gate.waitForArrivals(1)

        async let second = cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.remote
        }
        await gate.open()

        let firstAnswer = try await first
        let secondAnswer = try await second
        #expect(firstAnswer == local)
        #expect(secondAnswer == local)
        #expect(await gate.calls == 1)
    }

    @Test("a ref that moves mid-flight does not join the flight it invalidated", .timeLimit(.minutes(1)))
    func doesNotJoinAStaleFlight() async throws {
        let cache = BaselineCache()
        let gate = Gate()

        async let before = cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.local
        }
        async let after = cache.baseline(worktree: "/w", base: "main", fingerprint: "b") {
            await gate.arrive()
            return self.remote
        }
        await gate.waitForArrivals(2)
        await gate.open()

        let beforeAnswer = try await before
        let afterAnswer = try await after
        #expect(beforeAnswer == local)
        #expect(afterAnswer == remote)
        #expect(await gate.calls == 2)
    }

    @Test("an answer already remembered is not resolved again")
    func hitSkipsTheResolve() async throws {
        let cache = BaselineCache()
        let gate = Gate()
        await gate.open()
        await cache.remember(worktree: "/w", base: "main", fingerprint: "a", baseline: local)

        let answer = try await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.remote
        }

        #expect(answer == local)
        #expect(await gate.calls == 0)
    }

    @Test("what a flight resolved is remembered for the next caller")
    func remembersWhatItResolved() async throws {
        let cache = BaselineCache()
        let gate = Gate()
        await gate.open()

        _ = try await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.local
        }
        let again = try await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.remote
        }

        #expect(again == local)
        #expect(await gate.calls == 1)
    }

    @Test("a finished flight leaves nothing behind")
    func clearsTheFlight() async throws {
        let cache = BaselineCache()
        let gate = Gate()
        await gate.open()

        _ = try await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.local
        }

        #expect(await cache.flights == 0)
    }

    @Test("a resolve that throws is not remembered and leaves nothing behind")
    func doesNotRememberAFailure() async throws {
        let cache = BaselineCache()
        let gate = Gate()
        await gate.open()

        await #expect(throws: Boom.self) {
            _ = try await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
                await gate.arrive()
                throw Boom()
            }
        }

        #expect(await cache.flights == 0)
        #expect(await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") == nil)

        let answer = try await cache.baseline(worktree: "/w", base: "main", fingerprint: "a") {
            await gate.arrive()
            return self.local
        }
        #expect(answer == local)
        #expect(await gate.calls == 2)
    }

    private struct Boom: Error {}

    private actor Gate {
        private(set) var calls = 0
        private var isOpen = false
        private var held: [CheckedContinuation<Void, Never>] = []
        private var watchers: [(needed: Int, continuation: CheckedContinuation<Void, Never>)] = []

        func arrive() async {
            calls += 1
            let reached = calls
            watchers.removeAll { watcher in
                guard reached >= watcher.needed else { return false }
                watcher.continuation.resume()
                return true
            }
            guard !isOpen else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                held.append(continuation)
            }
        }

        func waitForArrivals(_ needed: Int) async {
            guard calls < needed else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                watchers.append((needed: needed, continuation: continuation))
            }
        }

        func open() {
            isOpen = true
            let waiting = held
            held = []
            for continuation in waiting { continuation.resume() }
        }
    }

    @Test("the table stays bounded")
    func bounded() async {
        let cache = BaselineCache()
        for index in 0..<(BaselineCache.limit + 20) {
            await cache.remember(
                worktree: "/w\(index)", base: "main", fingerprint: "f", baseline: local
            )
        }

        #expect(await cache.count == BaselineCache.limit)
        let newest = BaselineCache.limit + 19
        #expect(await cache.baseline(worktree: "/w\(newest)", base: "main", fingerprint: "f") == local)
    }
}
