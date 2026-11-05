import Testing
@testable import Core

@Suite("CanvasColourHex")
struct CanvasColourHexTests {
    @Test func hexRoundTripsOpaqueAndTranslucentColours() {
        for text in ["#FF8000", "#00000040", "#FFFFFF", "#1F293780"] {
            let parsed = CanvasColour(text)
            #expect(parsed?.hex == text)
        }
    }

    @Test func componentsAreClampedAndRounded() {
        let colour = CanvasColour(red: 1.4, green: -0.2, blue: 0.5, alpha: 1)
        #expect(colour.hex == "#FF0080")
    }
}
