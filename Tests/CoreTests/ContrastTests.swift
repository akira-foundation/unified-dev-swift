import Foundation
import Testing
@testable import Core

@Suite("Colour difference")
struct ContrastTests {
    @Test("CIEDE2000 answers the published pairs")
    func thePublishedPairs() {
        let pairs: [((l: Double, a: Double, b: Double), (l: Double, a: Double, b: Double), Double)] = [
            ((50, 2.6772, -79.7751), (50, 0, -82.7485), 2.0425),
            ((50, -1.3802, -84.2814), (50, 0, -82.7485), 1.0000),
            ((60.2574, -34.0099, 36.2677), (60.4626, -34.1751, 39.4387), 1.2644),
            ((63.0109, -31.0961, -5.8663), (62.8187, -29.7946, -4.0864), 1.2630),
            ((22.7233, 20.0904, -46.6940), (23.0331, 14.9730, -42.5619), 2.0373),
            ((2.0776, 0.0795, -1.1350), (0.9033, -0.0636, -0.5514), 0.9082),
        ]

        for (one, other, expected) in pairs {
            let measured = Contrast.deltaE(one, other)
            #expect(
                abs(measured - expected) < 0.0001,
                "\(one) against \(other): \(measured) rather than \(expected)"
            )
        }
    }

    @Test("the difference is symmetric, and zero for one colour")
    func theShapeOfTheAnswer() {
        #expect(Contrast.deltaE(0x0C7A6E, 0x0C7A6E) == 0)
        let forwards = Contrast.deltaE(PaletteInk.running.light, PaletteInk.warning.light)
        let backwards = Contrast.deltaE(PaletteInk.warning.light, PaletteInk.running.light)
        #expect(abs(forwards - backwards) < 0.0001)
    }

    @Test("Lab is measured from sRGB the way the standard says")
    func theConversionIsTheStandardOne() {
        let white = Contrast.lab(of: 0xFFFFFF)
        #expect(abs(white.l - 100) < 0.01)
        #expect(abs(white.a) < 0.01)
        #expect(abs(white.b) < 0.01)

        let black = Contrast.lab(of: 0x000000)
        #expect(abs(black.l) < 0.0001)

        let grey = Contrast.lab(of: 0x808080)
        #expect(abs(grey.l - 53.585) < 0.01)
        #expect(abs(grey.a) < 0.01)
        #expect(abs(grey.b) < 0.01)
    }

    @Test("both standards' knees classify every channel the same way")
    func theTwoThresholdsAgreeEverywhere() {
        func linear(_ channel: UInt32, knee: Double) -> Double {
            let value = Double(channel) / 255
            return value <= knee ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        for channel in UInt32(0)...255 {
            let wcag = linear(channel, knee: 0.03928)
            let srgb = linear(channel, knee: 0.04045)
            #expect(wcag == srgb, "channel \(channel)")

            let grey = channel << 16 | channel << 8 | channel
            let luminance = Contrast.relativeLuminance(of: grey)
            #expect(abs(luminance - srgb) < 1e-12, "channel \(channel)")
        }
    }

    @Test("a colour comes apart into the channels it was written with")
    func channelsAreUnpackedInWritingOrder() {
        let (r, g, b) = Contrast.channels(of: 0x1A2B3C)
        #expect((r, g, b) == (0x1A, 0x2B, 0x3C))
        #expect(Contrast.channels(of: 0x000000) == (0, 0, 0))
        #expect(Contrast.channels(of: 0xFFFFFF) == (255, 255, 255))
    }
}
