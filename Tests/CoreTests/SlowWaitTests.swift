import Testing
@testable import Core

@Suite("When a wait is worth saying so")
struct SlowWaitTests {
    @Test("nothing at all before the threshold")
    func silentUntilTheThreshold() {
        #expect(!SlowWait.isShowing(waited: .zero))
        #expect(!SlowWait.isShowing(waited: .milliseconds(1)))
        #expect(!SlowWait.isShowing(waited: SlowWait.threshold - .milliseconds(1)))
    }

    @Test("something once the threshold has passed")
    func showsOnceTheThresholdPasses() {
        #expect(SlowWait.isShowing(waited: SlowWait.threshold))
        #expect(SlowWait.isShowing(waited: SlowWait.threshold + .milliseconds(1)))
        #expect(SlowWait.isShowing(waited: .seconds(30)))
    }

    @Test("a wait that has already ended says nothing, however long it ran")
    func aFinishedWaitSaysNothing() {
        #expect(!SlowWait.isShowing(waited: .seconds(30), isOver: true))
        #expect(!SlowWait.isShowing(waited: SlowWait.threshold, isOver: true))
        #expect(!SlowWait.isShowing(waited: .zero, isOver: true))
    }

    @Test("the threshold can be moved without moving the rule")
    func theThresholdIsAParameter() {
        #expect(SlowWait.isShowing(waited: .milliseconds(100), threshold: .milliseconds(50)))
        #expect(!SlowWait.isShowing(waited: .milliseconds(100), threshold: .seconds(2)))
    }

    @Test("the quiet is exactly what is left of the threshold")
    func quietIsTheRemainder() {
        #expect(SlowWait.quiet() == SlowWait.threshold)
        #expect(SlowWait.quiet(after: .milliseconds(200)) == SlowWait.threshold - .milliseconds(200))
    }

    @Test("there is nothing left to stay quiet for once the threshold is reached")
    func quietEndsAtTheThreshold() {
        #expect(SlowWait.quiet(after: SlowWait.threshold) == nil)
        #expect(SlowWait.quiet(after: .seconds(10)) == nil)
    }

    @Test("the quiet ends exactly where the spinner starts")
    func thePairMeet() {
        var waited = Duration.zero
        while let quiet = SlowWait.quiet(after: waited) {
            #expect(!SlowWait.isShowing(waited: waited))
            waited += quiet
        }
        #expect(SlowWait.isShowing(waited: waited))
    }
}
