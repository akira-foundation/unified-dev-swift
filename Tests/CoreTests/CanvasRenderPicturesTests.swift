import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Core

private final class DecodedSides: @unchecked Sendable {
    private let lock = NSLock()
    private var sides: [Int] = []

    var all: [Int] { lock.withLock { sides } }

    func note(_ side: Int) { lock.withLock { sides.append(side) } }
}

@Suite("Pictures drawn into one render are decoded at their size and held to a cap")
struct CanvasRenderPicturesTests {
    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "canvas-render-pictures-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func png(_ name: String, side: Int) throws {
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let url = folder.appending(path: name)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    private func pictures(scale: Double = 1, limit: Int = CanvasRenderPictures.byteLimit, sides: DecodedSides) -> CanvasRenderPictures {
        CanvasRenderPictures(documentPath: folder.appending(path: "doc.udcanvas").path, worktree: folder.path, pixelsPerPoint: scale, limit: limit) { path, side in
            sides.note(side)
            return CanvasImageFile.decoded(path, longestSide: side)
        }
    }

    private let element = CanvasSize(width: 100, height: 100)

    @Test func aPictureIsDecodedAtTheElementTimesTheRenderScale() throws {
        try png("big.png", side: 2_048)
        let sides = DecodedSides()
        var render = pictures(scale: 2, sides: sides)

        let drawn = render.image("big.png", size: element)
        let image = try #require(drawn)

        #expect(sides.all == [256])
        #expect(image.width == 256)
        #expect(render.skipped.isEmpty)
    }

    @Test func aPictureUsedTwiceIsDecodedOnce() throws {
        try png("big.png", side: 2_048)
        let sides = DecodedSides()
        var render = pictures(sides: sides)

        _ = render.image("big.png", size: element)
        _ = render.image("big.png", size: CanvasSize(width: 50, height: 50))

        #expect(sides.all == [128])
    }

    @Test func aLargerUseOfAHeldPictureReplacesItAndCountsOnce() throws {
        try png("big.png", side: 2_048)
        let sides = DecodedSides()
        var render = pictures(sides: sides)

        _ = render.image("big.png", size: CanvasSize(width: 50, height: 50))
        let drawn = render.image("big.png", size: CanvasSize(width: 500, height: 500))
        let larger = try #require(drawn)

        #expect(sides.all == [64, 512])
        #expect(larger.width == 512)
        #expect(render.bytesHeld == larger.bytesPerRow * larger.height)
    }

    @Test func picturesPastTheCapAreSkippedAndNamedWhileTheFirstStillDraw() throws {
        for index in 0..<40 { try png("p\(index).png", side: 1_024) }
        let sides = DecodedSides()
        let limit = 512 * 512 * 4 * 3
        var render = pictures(limit: limit, sides: sides)
        var drawn: [String] = []

        for index in 0..<40 where render.image("p\(index).png", size: CanvasSize(width: 512, height: 512)) != nil {
            drawn.append("p\(index).png")
        }

        #expect(drawn == ["p0.png", "p1.png", "p2.png"])
        #expect(render.skipped == (3..<40).map { "p\($0).png" })
        #expect(render.bytesHeld <= limit)
        #expect(sides.all.count == 3)
    }

    @Test func aMissingPictureIsNotCalledSkipped() {
        let sides = DecodedSides()
        var render = pictures(sides: sides)

        let drawn = render.image("not-there.png", size: element)

        #expect(drawn == nil)
        #expect(render.skipped.isEmpty)
        #expect(sides.all.isEmpty)
    }

    @Test func aPictureDeeperThanEstimatedIsSkippedOnceDecoded() throws {
        try png("deep.png", side: 1_024)
        var render = CanvasRenderPictures(
            documentPath: folder.appending(path: "doc.udcanvas").path, worktree: folder.path, pixelsPerPoint: 1, limit: 128 * 128 * 6
        ) { _, side in
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 16, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            return context?.makeImage()
        }

        let drawn = render.image("deep.png", size: CanvasSize(width: 128, height: 128))

        #expect(drawn == nil)
        #expect(render.skipped == ["deep.png"])
        #expect(render.bytesHeld == 0)
    }
}
