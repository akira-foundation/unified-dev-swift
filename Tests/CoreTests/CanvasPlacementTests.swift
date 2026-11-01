import Testing
@testable import Core

@Suite("Where a canvas opens")
struct CanvasPlacementTests {
    @Test(
        "the decision follows the canvas, the focus, the caller and the tab in front",
        arguments: [
            (true, true, true, true, CanvasPlacement.retarget(bringToFront: true)),
            (true, false, true, true, CanvasPlacement.retarget(bringToFront: false)),
            (false, true, true, true, CanvasPlacement.besideCaller),
            (false, true, false, true, CanvasPlacement.newTab(inFront: true)),
            (false, false, true, true, CanvasPlacement.newTab(inFront: false)),
            (false, false, true, false, CanvasPlacement.newTab(inFront: true)),
        ]
    )
    func decide(
        hasCanvas: Bool, focus: Bool, hasCaller: Bool, hasTabInFront: Bool, expected: CanvasPlacement
    ) {
        #expect(
            CanvasPlacement.decide(
                hasCanvas: hasCanvas, focus: focus, hasCaller: hasCaller, hasTabInFront: hasTabInFront
            ) == expected
        )
    }
}
