import CoreGraphics
import Testing
@testable import Core

struct FullScreenToolbarGroundTests {
    @Test func shortensAGroundTallerThanTheToolbarUnderTheNotch() {
        #expect(correct(current: 85) == 52)
    }

    @Test func leavesAGroundAlreadyAtTheToolbarHeight() {
        #expect(correct(current: 52) == nil)
    }

    @Test func leavesAScreenWithoutANotchAlone() {
        #expect(correct(current: 85, screenTopInset: 0) == nil)
    }

    @Test func leavesTheGroundAloneWithoutAToolbar() {
        #expect(correct(current: 85, toolbarBand: 0) == nil)
    }

    private func correct(
        current: CGFloat,
        toolbarBand: CGFloat = 52,
        screenTopInset: CGFloat = 32
    ) -> CGFloat? {
        FullScreenToolbarGround.correctedHeight(
            current: current,
            toolbarBand: toolbarBand,
            screenTopInset: screenTopInset
        )
    }
}
