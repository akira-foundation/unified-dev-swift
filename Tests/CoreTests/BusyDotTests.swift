import Testing
@testable import Core

@Suite("The pulse a busy mark moves on")
struct BusyDotTests {
    @Test("a pulse divides the marks that move more slowly")
    func periodDividesTheSlowerMarks() {
        #expect(BusyDot.period == 1.5)
        #expect(BusyRule.period == BusyDot.period)
        #expect((BusyBreath.period / BusyDot.period).truncatingRemainder(dividingBy: 1) == 0)
    }

    @Test("it swells as it fades")
    func swellsAsItFades() {
        #expect(BusyDot.scale(at: 1) > BusyDot.scale(at: 0))
        #expect(BusyDot.opacity(at: 1) < BusyDot.opacity(at: 0))
    }

    @Test("it never goes out and never vanishes")
    func neverGoesOut() {
        for step in 0...100 {
            let pulse = Double(step) / 100
            #expect(BusyDot.opacity(at: pulse) >= 0.5)
            #expect(BusyDot.scale(at: pulse) >= 1)
        }
    }

    @Test("the figure is only ever scaled down")
    func onlyEverScaledDown() {
        for step in 0...100 {
            let pulse = Double(step) / 100
            #expect(BusyDot.pathScale(at: pulse) <= 1)
            #expect(BusyDot.pathScale(at: pulse) > 0)
        }
        #expect(abs(BusyDot.pathScale(at: 1) - 1) < 1e-12, "the top of the pulse is the path itself")
    }

    @Test("the resting figure is the whole mark")
    func restsWhole() {
        #expect(BusyDot.scale(at: BusyDot.resting) == 1)
        #expect(BusyDot.opacity(at: BusyDot.resting) == 1)
    }

    @Test("anything outside the pulse is held at its ends")
    func clamped() {
        #expect(BusyDot.scale(at: -1) == BusyDot.scale(at: 0))
        #expect(BusyDot.scale(at: 2) == BusyDot.scale(at: 1))
        #expect(BusyDot.opacity(at: -1) == BusyDot.opacity(at: 0))
        #expect(BusyDot.opacity(at: 2) == BusyDot.opacity(at: 1))
    }
}
