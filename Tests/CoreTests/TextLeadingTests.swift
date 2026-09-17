import Testing
import Foundation
@testable import Core

@Suite("How much air a line of transcript text gets")
struct TextLeadingTests {
    private static let bodySteps: [(size: Double, box: Double)] = [
        (12, 15), (13, 16), (15, 18), (17, 20), (20, 23),
    ]

    @Test("the line height lands on the ratio at every chat text size")
    func holdsTheRatioAcrossTheRange() {
        for step in Self.bodySteps {
            let extra = TextLeading.overPointSize(lineHeight: step.box, pointSize: step.size)
            let ratio = (step.box + extra) / step.size
            #expect(abs(ratio - TextLeading.proseRatio) < 0.05)
        }
    }

    @Test("the new 15 point default adds five points to its native line box")
    func theDefaultMoves() {
        #expect(TextLeading.overPointSize(lineHeight: 18, pointSize: 15) == 5)
    }

    @Test("a fixed three points is what the ratio is not")
    func aConstantDriftsAndThisDoesNot() {
        let smallest = (15.0 + 3) / 12
        let largest = (23.0 + 3) / 20
        #expect(smallest - largest > 0.15)

        let ledSmallest = (15.0 + TextLeading.overPointSize(lineHeight: 15, pointSize: 12)) / 12
        let ledLargest = (23.0 + TextLeading.overPointSize(lineHeight: 23, pointSize: 20)) / 20
        #expect(abs(ledSmallest - ledLargest) < 0.05)
    }

    @Test("the answer is a whole number of points")
    func roundsToAPoint() {
        for step in Self.bodySteps {
            let extra = TextLeading.overPointSize(lineHeight: step.box, pointSize: step.size)
            #expect(extra == extra.rounded())
        }
    }

    @Test("a line box already past the ratio is left alone rather than crushed")
    func neverNegative() {
        #expect(TextLeading.overPointSize(lineHeight: 40, pointSize: 13) == 0)
    }

    @Test("nothing is added to a font that has no size")
    func refusesNonsense() {
        #expect(TextLeading.overPointSize(lineHeight: 0, pointSize: 13) == 0)
        #expect(TextLeading.overPointSize(lineHeight: 16, pointSize: 0) == 0)
    }

    @Test("the permission panel's command is unchanged at the default chat size")
    func codeHoldsItsFourPoints() {
        #expect(TextLeading.overLineBox(lineHeight: 13) == 4)
    }

    @Test("a command set larger keeps the ratio it was decided at")
    func codeHoldsItsRatio() {
        for box in [12.0, 13, 16, 17, 20] {
            let ratio = (box + TextLeading.overLineBox(lineHeight: box)) / box
            #expect(abs(ratio - TextLeading.codeRatio) < 0.05)
        }
    }

    @Test("code is measured against its box and prose against its size, and they do not agree")
    func theTwoDenominatorsAreNotOneDecision() {
        let prose = TextLeading.overPointSize(lineHeight: 16, pointSize: 13)
        let code = TextLeading.overLineBox(lineHeight: 16)
        #expect(prose != code)
    }
}
