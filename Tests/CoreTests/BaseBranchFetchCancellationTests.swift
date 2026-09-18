import Foundation
import Testing
@testable import Core

@Suite("Base branch fetches that are cancelled", .timeLimit(.minutes(1)))
struct BaseBranchFetchCancellationTests {
    private actor Latch {
        private var isOpen = false
        private var held: [CheckedContinuation<Void, Never>] = []

        func pass() async {
            guard !isOpen else { return }
            await withCheckedContinuation { held.append($0) }
        }

        func open() {
            isOpen = true
            for continuation in held { continuation.resume() }
            held = []
        }
    }

    private actor Calls {
        private(set) var count = 0
        private(set) var cancelledEnding = false

        func next() -> Int {
            count += 1
            return count
        }

        func noteCancelledEnding() {
            cancelledEnding = true
        }
    }

    @Test("a cut arriving while a cancelled fetch winds down waits for it, then fetches for itself",
          arguments: [false, true])
    func cutWaitsOutACancelledFlight(cancelledFetchesEveryBranch: Bool) async {
        let calls = Calls()
        let windDown = Latch()
        let second = Latch()
        let fetches = BaseBranchFetches { _, _, _ in
            let call = await calls.next()
            guard call == 1 else {
                await second.pass()
                return true
            }
            try? await Task.sleep(for: .seconds(30))
            await calls.noteCancelledEnding()
            await windDown.pass()
            return false
        }

        let earlier = Task {
            cancelledFetchesEveryBranch
                ? await fetches.refreshBranches(in: "/repo", remote: "origin")
                : await fetches.prefetch("main", in: "/repo", remote: "origin")
        }
        await waitUntil("the earlier fetch has started") { await calls.count == 1 }
        earlier.cancel()
        await waitUntil("the earlier fetch is winding down") { await calls.cancelledEnding }

        async let cut = fetches.refresh("main", in: "/repo", remote: "origin", acceptingWithin: .seconds(120))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await calls.count == 1)

        await windDown.open()
        #expect(await earlier.value == false)
        await waitUntil("the cut has started a fetch of its own") { await calls.count == 2 }
        #expect(await fetches.joined == 0)
        #expect(await fetches.flights == 1)

        await second.open()
        #expect(await cut == true)
        #expect(await fetches.flights == 0)
    }
}
