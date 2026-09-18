import Testing
@testable import Core

@Suite("Settling the review on a jump destination")
struct ReviewLandingTests {
    @Test("a quiet destination that was never seen in place scrolls again instead of settling")
    func unseenDestinationRetries() {
        var landing = ReviewLanding()
        landing.begin()
        let retries = landing.quietPeriodElapsed()
        #expect(retries)
        #expect(!landing.isSettled)
    }

    @Test("a destination reported in place settles once the review is quiet")
    func landedDestinationSettles() {
        var landing = ReviewLanding()
        landing.begin()
        landing.observe(landed: true)
        let retries = landing.quietPeriodElapsed()
        #expect(!retries)
        #expect(landing.isSettled)
    }

    @Test("a destination that moved away after landing is chased again")
    func movedDestinationRetries() {
        var landing = ReviewLanding()
        landing.begin()
        landing.observe(landed: true)
        landing.observe(landed: false)
        let retries = landing.quietPeriodElapsed()
        #expect(retries)
        #expect(!landing.isSettled)
    }

    @Test("a destination that never lands stops being chased after the retry limit")
    func retriesAreBounded() {
        var landing = ReviewLanding()
        landing.begin()
        var attempts = 0
        while !landing.isSettled, attempts < 100 {
            if landing.quietPeriodElapsed() { attempts += 1 }
        }
        #expect(landing.isSettled)
        #expect(attempts == ReviewLanding.retryLimit)
    }

    @Test("a new jump forgets the previous destination's landing and retries")
    func beginResets() {
        var landing = ReviewLanding()
        landing.begin()
        landing.observe(landed: true)
        _ = landing.quietPeriodElapsed()
        landing.begin()
        #expect(!landing.isSettled)
        let retries = landing.quietPeriodElapsed()
        #expect(retries)
    }

    @Test("reopening a settled destination keeps what was last seen of it")
    func reopenKeepsObservation() {
        var landing = ReviewLanding()
        landing.begin()
        landing.observe(landed: true)
        _ = landing.quietPeriodElapsed()
        landing.reopen()
        #expect(!landing.isSettled)
        let retries = landing.quietPeriodElapsed()
        #expect(!retries)
        #expect(landing.isSettled)
    }
}
