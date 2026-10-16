import CoreGraphics
import Foundation
import Testing
@testable import Core

@Suite("InkReading")
struct InkReadingTests {
    private static func image(
        width: Int, height: Int, painting: (Int, Int) -> (UInt8, UInt8, UInt8)
    ) -> CGImage {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let (red, green, blue) = painting(x, y)
                let offset = y * bytesPerRow + x * 4
                pixels[offset] = red
                pixels[offset + 1] = green
                pixels[offset + 2] = blue
                pixels[offset + 3] = 255
            }
        }
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let made = context?.makeImage() else {
            fatalError("the test could not make an image to read")
        }
        return made
    }

    private static let stride = 400 / InkReading.samplesAcross

    private static func flat(_ shade: UInt8, width: Int = 400, height: Int = 300) -> CGImage {
        image(width: width, height: height) { _, _ in (shade, shade, shade) }
    }

    @Test("a window holding one colour puts no ink on the screen, whatever the colour")
    func oneColourIsNoInk() {
        for shade in [UInt8(0), 128, 255] {
            let reading = InkReading.of(Self.flat(shade))
            #expect(reading.ink == 0)
            #expect(reading.failure == nil)
            #expect(reading.samples > 0)
        }
    }

    @Test("a column of alternating stripes puts ink on every sample it is read at")
    func everyStripeIsAnEdge() {
        let striped = Self.image(width: 400, height: 300) { x, _ in
            (x / Self.stride).isMultiple(of: 2) ? (0, 0, 0) : (255, 255, 255)
        }
        let reading = InkReading.of(striped)
        #expect(reading.ink == 1)
        #expect(reading.samples > 0)
    }

    @Test("a shade too close to its neighbour is not counted as an edge")
    func aFaintStepIsNotAnEdge() {
        let faint = Self.image(width: 400, height: 300) { x, _ in
            (x / Self.stride).isMultiple(of: 2) ? (128, 128, 128) : (131, 131, 131)
        }
        #expect(InkReading.of(faint).ink == 0)

        let plain = Self.image(width: 400, height: 300) { x, _ in
            (x / Self.stride).isMultiple(of: 2) ? (128, 128, 128) : (148, 148, 148)
        }
        #expect(InkReading.of(plain).ink > 0)
    }

    @Test("a capture too small to read says so instead of answering zero")
    func anImageTooSmallIsNotReadAsBlank() {
        for side in [1, 2, 4] {
            let reading = InkReading.of(Self.flat(200, width: side, height: side))
            #expect(reading.failure != nil)
            #expect(reading.ink == WindowInk.unread)
            #expect(reading.samples == 0)
            #expect(reading.width == side)
        }
        #expect(InkReading.of(Self.flat(200, width: 5, height: 5)).failure == nil)
        #expect(InkReading.leastSide == 4)
    }

    @Test("the mean is a share of white, so it never leaves nought to one")
    func theMeanStaysWithinItsOwnScale() {
        let white = InkReading.of(Self.flat(255))
        #expect(white.mean == 1)
        #expect(InkReading.of(Self.flat(0)).mean == 0)
        let half = InkReading.of(Self.flat(128))
        #expect(half.mean > 0.49 && half.mean < 0.51)
        for shade in [UInt8(0), 64, 128, 192, 255] {
            let reading = InkReading.of(Self.flat(shade))
            #expect(reading.mean >= 0 && reading.mean <= 1)
        }
    }

    @Test("a window larger than the grid is read at the grid, not pixel by pixel")
    func aLargeWindowIsSampled() {
        let reading = InkReading.of(Self.flat(255, width: 1_600, height: 900))
        #expect(reading.width == 1_600)
        #expect(reading.samples < 1_600 * 900)
        #expect(reading.samples > 0)
    }

    @Test("a reading that was never taken is not a reading of an empty window")
    func anUntakenReadingIsNotBlank() {
        let reading = InkReading()
        #expect(reading.ink == WindowInk.unread)
        #expect(!WindowInk(onArrival: reading.ink, afterRedraw: reading.ink).isReadable)
    }
}
