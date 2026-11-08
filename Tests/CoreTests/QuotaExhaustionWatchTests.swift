import Testing
import Foundation
@testable import Core

@Suite("Quota exhaustion watch")
struct QuotaExhaustionWatchTests {
    private let workspace = WorkspaceID("w1")

    private func event(status: String = "allowed", utilization: Double? = nil, resetsAt: Double = 1_800_000_000) -> Data {
        var info = "\"status\":\"\(status)\",\"rateLimitType\":\"five_hour\",\"resetsAt\":\(resetsAt)"
        if let utilization { info += ",\"utilization\":\(utilization)" }
        return Data("{\"type\":\"rate_limit_event\",\"rate_limit_info\":{\(info)}}".utf8)
    }

    @Test("a refused turn counts as exhausted even with no utilisation")
    func refusedWithoutUtilisation() {
        var watch = QuotaExhaustionWatch()

        #expect(watch.newlyExhausted(fromRateLimitEvent: event(status: "rejected"), in: workspace).count == 1)
    }

    @Test("a window used up counts, one still in use does not")
    func spentWindow() {
        var watch = QuotaExhaustionWatch()

        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 0.8), in: workspace).isEmpty)
        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 1.0), in: workspace).count == 1)
    }

    @Test("the same window is told once until it resets")
    func toldOnce() {
        var watch = QuotaExhaustionWatch()

        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 1.0), in: workspace).count == 1)
        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 1.0), in: workspace).isEmpty)
        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 0.1, resetsAt: 1_800_018_000), in: workspace).isEmpty)
        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 1.0, resetsAt: 1_800_018_000), in: workspace).count == 1)
    }

    @Test("each workspace is told on its own")
    func perWorkspace() {
        var watch = QuotaExhaustionWatch()

        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 1.0), in: workspace).count == 1)
        #expect(watch.newlyExhausted(fromRateLimitEvent: event(utilization: 1.0), in: WorkspaceID("w2")).count == 1)
    }
}
