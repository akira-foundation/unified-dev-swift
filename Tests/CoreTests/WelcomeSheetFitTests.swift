import CoreGraphics
import Testing
@testable import Core

@Suite("WelcomeSheetFit")
struct WelcomeSheetFitTests {
    @Test("A display shorter than the shortest laptop lowers the limit to what it leaves")
    func shorterDisplay() {
        let visible: CGFloat = 767
        let limit = WelcomeSheetFit.heightLimit(forVisibleHeight: visible)
        #expect(limit == visible - WelcomeSheetFit.titleBarHeight - WelcomeSheetFit.screenMargin * 2)
        #expect(limit < WelcomeSheetFit.heightLimit)
    }

    @Test("A taller display does not raise the limit past the shortest laptop")
    func tallerDisplay() {
        #expect(WelcomeSheetFit.heightLimit(forVisibleHeight: 1440) == WelcomeSheetFit.heightLimit)
        #expect(WelcomeSheetFit.heightLimit(forVisibleHeight: 1084) == WelcomeSheetFit.heightLimit)
    }

    @Test("No display at all leaves the shortest laptop as the floor")
    func noDisplay() {
        #expect(WelcomeSheetFit.heightLimit(forVisibleHeight: nil) == WelcomeSheetFit.heightLimit)
    }

    @Test("The window the limit allows fits the display it was measured against",
          arguments: [700.0, 767.0, 867.0, 1084.0, 1440.0] as [CGFloat])
    func windowFits(visible: CGFloat) {
        let window = WelcomeSheetFit.heightLimit(forVisibleHeight: visible) + WelcomeSheetFit.titleBarHeight
        #expect(window <= visible)
        #expect(window <= WelcomeSheetFit.shortestLaptopVisibleHeight)
    }
}
