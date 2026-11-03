import Testing
@testable import Core

@Suite("Capture wait")
struct CaptureWaitTests {
    @Test func turnsSecondsIntoTicksOfTheLengthItIsGiven() {
        #expect(CaptureWait.ticks(seconds: 150, everyMilliseconds: 250) == 600)
        #expect(CaptureWait.ticks(seconds: 10, everyMilliseconds: 250) == 40)
        #expect(CaptureWait.ticks(seconds: 1, everyMilliseconds: 1_000) == 1)
    }

    @Test func waitsAtLeastOneSecondAndAtLeastOneTick() {
        #expect(CaptureWait.ticks(seconds: 0, everyMilliseconds: 250) == 4)
        #expect(CaptureWait.ticks(seconds: -30, everyMilliseconds: 250) == 4)
        #expect(CaptureWait.ticks(seconds: 1, everyMilliseconds: 0) == 1_000)
    }
}
