import CoreGraphics
import Testing
@testable import Core

struct FullScreenToolbarGroundTests {
    @Test func appliesInFullScreenUnderTheNotch() {
        #expect(FullScreenToolbarGround.applies(isFullScreen: true, screenTopInset: 32))
    }

    @Test func doesNotApplyToAWindowedTitleBar() {
        #expect(!FullScreenToolbarGround.applies(isFullScreen: false, screenTopInset: 32))
    }

    @Test func doesNotApplyToAScreenWithoutANotch() {
        #expect(!FullScreenToolbarGround.applies(isFullScreen: true, screenTopInset: 0))
    }

    @Test func shortensAGroundTallerThanTheToolbar() {
        #expect(FullScreenToolbarGround.correctedHeight(current: 85, toolbarBand: 52) == 52)
    }

    @Test func shortensAGroundJustBeyondTheTolerance() {
        #expect(FullScreenToolbarGround.correctedHeight(current: 52.75, toolbarBand: 52) == 52)
    }

    @Test func leavesAGroundWithinTheTolerance() {
        #expect(FullScreenToolbarGround.correctedHeight(current: 52.5, toolbarBand: 52) == nil)
    }

    @Test func neverGrowsAGroundShorterThanTheToolbar() {
        #expect(FullScreenToolbarGround.correctedHeight(current: 40, toolbarBand: 52) == nil)
    }

    @Test func leavesTheGroundAloneWithoutAToolbar() {
        #expect(FullScreenToolbarGround.correctedHeight(current: 85, toolbarBand: 0) == nil)
    }
}
