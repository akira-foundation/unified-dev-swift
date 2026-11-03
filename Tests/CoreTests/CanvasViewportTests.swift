import Testing
@testable import Core

@Suite("CanvasViewport")
struct CanvasViewportTests {
    private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    @Test func conversionRoundTrips() {
        let viewport = CanvasViewport(zoom: 2.5, offset: CanvasPoint(x: 40, y: -12))
        let point = CanvasPoint(x: 310, y: 77)
        let back = viewport.toCanvas(viewport.toScreen(point))
        #expect(near(back.x, point.x) && near(back.y, point.y))
    }

    @Test func zoomKeepsThePointUnderTheCursor() {
        var viewport = CanvasViewport(zoom: 1, offset: CanvasPoint(x: 10, y: 20))
        let cursor = CanvasPoint(x: 200, y: 150)
        let before = viewport.toCanvas(cursor)
        viewport.zoom(by: 1.8, around: cursor)
        let after = viewport.toCanvas(cursor)
        #expect(near(viewport.zoom, 1.8))
        #expect(near(before.x, after.x) && near(before.y, after.y))
    }

    @Test func zoomStaysInRange() {
        var viewport = CanvasViewport()
        viewport.zoom(by: 1000, around: CanvasPoint(x: 0, y: 0))
        let high = viewport.zoom
        viewport.zoom(by: 0.000001, around: CanvasPoint(x: 0, y: 0))
        #expect(high == CanvasViewport.zoomRange.upperBound)
        #expect(viewport.zoom == CanvasViewport.zoomRange.lowerBound)
    }

    @Test func fittingCentresTheRect() {
        let rect = CanvasRect(x: 100, y: 50, width: 1000, height: 500)
        let viewport = CanvasViewport.fitting(rect, in: CanvasSize(width: 500, height: 500))
        let centre = viewport.toScreen(CanvasPoint(x: 600, y: 300))
        #expect(near(centre.x, 250) && near(centre.y, 250))
        #expect(viewport.zoom < 0.5)
        #expect(viewport.zoom > 0.4)
    }
}

@Suite("CanvasColour")
struct CanvasColourTests {
    @Test func parsesSixAndEightDigitForms() {
        let opaque = CanvasColour("#FF8000")
        let faded = CanvasColour("#00FF0080")
        #expect(opaque == CanvasColour(red: 1, green: 128.0 / 255, blue: 0, alpha: 1))
        #expect(faded?.alpha == 128.0 / 255)
    }

    @Test(arguments: ["", "red", "#FFF", "#GGGGGG", "FF8000", "#FF80001", "#+F8000"])
    func refusesAnythingElse(_ text: String) {
        #expect(CanvasColour(text) == nil)
    }
}

@Suite("CanvasFontWeight and CanvasRect union")
struct CanvasFontWeightTests {
    @Test func everyWeightMapsToItself() {
        for weight in CanvasFontWeight.allCases {
            #expect(CanvasFontWeight.nearest(to: weight.value) == weight)
        }
    }

    @Test func valuesSnapToTheNearestWeight() {
        #expect(CanvasFontWeight.nearest(to: 0.05) == .regular)
        #expect(CanvasFontWeight.nearest(to: 0.45) == .bold)
        #expect(CanvasFontWeight.nearest(to: 5) == .black)
        #expect(CanvasFontWeight.nearest(to: -5) == .ultraLight)
    }

    @Test func unionCoversEveryRect() {
        let union = CanvasRect.union(of: [
            CanvasRect(x: 0, y: 0, width: 100, height: 100),
            CanvasRect(x: 200, y: -50, width: 100, height: 100),
        ])
        #expect(union == CanvasRect(x: 0, y: -50, width: 300, height: 150))
        #expect(CanvasRect.union(of: []) == nil)
    }
}
