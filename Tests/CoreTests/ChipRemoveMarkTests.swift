import Foundation
import Testing
@testable import Core

@Suite("The close control on a chip")
struct ChipRemoveMarkTests {
    @Test("the X is over half the disc and never fills it")
    func glyphLeavesPlateAround() {
        for diameter in stride(from: CGFloat(10), through: 24, by: 1) {
            let glyph = ChipRemoveMark.glyphPointSize(diameter: diameter)
            #expect(glyph > diameter / 2)
            #expect(glyph < diameter)
        }
    }

    @Test("the size follows the slot rather than a number written twice")
    func glyphScalesWithDiameter() {
        #expect(ChipRemoveMark.glyphPointSize(diameter: 28) == ChipRemoveMark.glyphPointSize(diameter: 14) * 2)
        #expect(ChipRemoveMark.glyphPointSize(diameter: 0) == 0)
    }

    @Test("the plate on an emphasized fill lifts under the pointer and stays a wash")
    func emphasisPlateLifts() {
        #expect(ChipRemoveMark.emphasisPlateHovered > ChipRemoveMark.emphasisPlate)
        #expect(ChipRemoveMark.emphasisPlate > 0)
        #expect(ChipRemoveMark.emphasisPlateHovered < 1)
        #expect(ChipRemoveMark.emphasisRing > ChipRemoveMark.emphasisPlateHovered)
        #expect(ChipRemoveMark.emphasisRing < 1)
    }
}
