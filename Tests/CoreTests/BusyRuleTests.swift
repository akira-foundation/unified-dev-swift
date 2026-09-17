import Testing
@testable import Core

@Suite("The pulse the activity rule moves on")
struct BusyRuleTests {
    @Test("it brightens to the accent undiluted")
    func brightensToTheAccent() {
        #expect(BusyRule.opacity(at: 1) > BusyRule.opacity(at: 0))
        #expect(BusyRule.opacity(at: 1) == 1)
    }

    @Test("it never goes out")
    func neverGoesOut() {
        for step in 0...100 {
            let pulse = Double(step) / 100
            #expect(BusyRule.opacity(at: pulse) >= BusyRule.restingOpacity)
            #expect(BusyRule.opacity(at: pulse) <= 1)
        }
    }

    @Test("the still figure is the bottom of the pulse")
    func restsAtTheBottom() {
        #expect(BusyRule.opacity(at: BusyRule.resting) == BusyRule.restingOpacity)
    }

    @Test("the rule and the dot are on one wave")
    func sharesTheDotsWave() {
        #expect(BusyRule.period == BusyDot.period)
        #expect((BusyBreath.period / BusyRule.period).truncatingRemainder(dividingBy: 1) == 0)
    }

    @Test("anything outside the pulse is held at its ends")
    func clamped() {
        #expect(BusyRule.opacity(at: -1) == BusyRule.opacity(at: 0))
        #expect(BusyRule.opacity(at: 2) == BusyRule.opacity(at: 1))
    }

    @Test("it thickens as well as brightens")
    func thickensAsWellAsBrightens() {
        #expect(BusyRule.height(at: 1) > BusyRule.height(at: 0))
        #expect(BusyRule.height(at: BusyRule.resting) == BusyRule.restingHeight)
        #expect(BusyRule.height(at: 1) == BusyRule.peakHeight)
        #expect(BusyRule.height(at: -1) == BusyRule.height(at: 0))
        #expect(BusyRule.height(at: 2) == BusyRule.height(at: 1))
    }

    @Test("the still figure is the hairline itself")
    func restsOnTheHairline() {
        #expect(BusyRule.restingHeight == 1)
    }
}
