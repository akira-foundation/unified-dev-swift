import Testing
import CoreGraphics
@testable import Core

@Suite("SplitPaneClip")
struct SplitPaneClipTests {
    private let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)

    @Test("a pane at the top of the column opens its clip under the toolbar")
    func topPaneReachesUnderTheBar() {
        let pane = SplitPaneFrame(pane: "a", frame: CGRect(x: 0, y: 0, width: 400, height: 300))

        #expect(pane.touchesTop)
        #expect(pane.clip(of: bounds) == CGRect(
            x: 0, y: -SplitPaneFrame.underBarReach,
            width: 400, height: 300 + SplitPaneFrame.underBarReach
        ))
    }

    @Test("a pane below a horizontal divider keeps its clip to its own bounds")
    func lowerPaneStaysInside() {
        let pane = SplitPaneFrame(pane: "b", frame: CGRect(x: 0, y: 151, width: 400, height: 149))

        #expect(!pane.touchesTop)
        #expect(pane.clip(of: bounds) == bounds)
    }

    @Test("a pane side by side with another at the top still reaches under the toolbar")
    func sideBySideTopPane() {
        let pane = SplitPaneFrame(pane: "c", frame: CGRect(x: 201, y: 0, width: 199, height: 300))

        #expect(pane.touchesTop)
    }
}
