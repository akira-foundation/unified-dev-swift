import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Core

private final class DecodeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var sides: [Int] = []

    var count: Int { lock.withLock { sides.count } }

    func note(_ side: Int) { lock.withLock { sides.append(side) } }
}

@Suite("Pictures on a canvas are decoded off the window and held to a budget", .scratchDirectory)
struct CanvasImageCacheTests {
    private let folder: URL
    private let need = CanvasImageNeed(width: 128, height: 128, pixelsPerPoint: 1)

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "canvas-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func bitmap(side: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return try #require(context.makeImage())
    }

    @discardableResult
    private func png(_ name: String, side: Int = 256) throws -> String {
        let url = folder.appending(path: name)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try bitmap(side: side), nil)
        #expect(CGImageDestinationFinalize(destination))
        return url.path
    }

    private func counting(_ counter: DecodeCounter) -> CanvasImageCache.Decoder {
        { path, side in
            counter.note(side)
            return CanvasImageFile.decoded(path, longestSide: side)
        }
    }

    private func leased(_ lookup: CanvasImageLookup) throws -> CanvasImageLease {
        guard case .ready(let lease) = lookup else {
            Issue.record("not ready: \(lookup)")
            throw CocoaError(.coderReadCorrupt)
        }
        return lease
    }

    private func bytes(longestSide side: Int) -> Int { side * side * 4 }

    private func settled(_ cache: CanvasImageCache) async throws {
        for _ in 0..<2_000 where await cache.leasesHeld > 0 {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await cache.leasesHeld == 0)
    }

    @Test func fiftyElementsOnOnePictureDecodeItOnce() async throws {
        let path = try png("one.png")
        let counter = DecodeCounter()
        let cache = CanvasImageCache(decode: counting(counter))

        var leases: [CanvasImageLease] = []
        for _ in 0..<50 { leases.append(try leased(await cache.lookup(resolved: path, need: need))) }

        #expect(counter.count == 1)
        #expect(leases.count == 50)
    }

    @Test func aPictureRewrittenOnDiskIsDecodedAgain() async throws {
        let path = try png("changing.png", side: 128)
        let counter = DecodeCounter()
        let cache = CanvasImageCache(decode: counting(counter))
        _ = try leased(await cache.lookup(resolved: path, need: need))

        try png("changing.png", side: 256)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: path)
        let again = try leased(await cache.lookup(resolved: path, need: CanvasImageNeed(width: 256, height: 256, pixelsPerPoint: 1)))

        #expect(counter.count == 2)
        #expect(again.image.width == 256)
    }

    @Test func aPictureIsDecodedAtWhatTheElementNeeds() async throws {
        let path = try png("large.png", side: 512)
        let cache = CanvasImageCache()

        let lease = try leased(await cache.lookup(resolved: path, need: CanvasImageNeed(width: 100, height: 100, pixelsPerPoint: 1)))

        #expect(lease.image.width == 128)
        #expect(await cache.bytesHeld == lease.image.bytesPerRow * lease.image.height)
    }

    @Test func aPictureAlreadyHeldLargerServesASmallerNeedWithoutDecoding() async throws {
        let path = try png("held.png", side: 512)
        let counter = DecodeCounter()
        let cache = CanvasImageCache(decode: counting(counter))
        let large = try leased(await cache.lookup(resolved: path, need: CanvasImageNeed(width: 512, height: 512, pixelsPerPoint: 1)))

        let small = try leased(await cache.lookup(resolved: path, need: CanvasImageNeed(width: 64, height: 64, pixelsPerPoint: 1)))

        #expect(counter.count == 1)
        #expect(small.image.width == large.image.width)
    }

    @Test func thePictureUsedLongestAgoGoesWhenTheBudgetIsFull() async throws {
        let first = try png("first.png")
        let second = try png("second.png")
        let third = try png("third.png")
        let counter = DecodeCounter()
        let cache = CanvasImageCache(limit: bytes(longestSide: 128) * 2, decode: counting(counter))
        let limit = bytes(longestSide: 128) * 2

        _ = try leased(await cache.lookup(resolved: first, need: need))
        _ = try leased(await cache.lookup(resolved: second, need: need))
        try await settled(cache)
        _ = try leased(await cache.lookup(resolved: first, need: need))
        try await settled(cache)
        _ = try leased(await cache.lookup(resolved: third, need: need))
        #expect(await cache.bytesHeld <= limit)
        #expect(counter.count == 3)

        try await settled(cache)
        _ = try leased(await cache.lookup(resolved: first, need: need))
        #expect(counter.count == 3)
    }

    @Test func aPictureOnScreenIsNeverEvictedAndTheNextOneComesSmaller() async throws {
        let first = try png("pinned.png")
        let second = try png("next.png")
        let limit = bytes(longestSide: 128) + bytes(longestSide: 64)
        let cache = CanvasImageCache(limit: limit)

        let pinned = try leased(await cache.lookup(resolved: first, need: need))
        let smaller = try leased(await cache.lookup(resolved: second, need: need))

        #expect(pinned.image.width == 128)
        #expect(smaller.image.width == 64)
        #expect(await cache.bytesHeld <= limit)
    }

    @Test func aTinyPictureIsNotTurnedAwayForBeingTiny() async throws {
        let path = try png("tiny.png", side: 16)
        let cache = CanvasImageCache()

        let lease = try leased(await cache.lookup(resolved: path, need: need))

        #expect(lease.image.width == 16)
    }

    @Test func aPictureWithNoRoomAtAnySizeSaysSoAndHoldsNothingMore() async throws {
        let first = try png("full.png")
        let second = try png("late.png")
        let limit = bytes(longestSide: 128)
        let cache = CanvasImageCache(limit: limit)

        let pinned = try leased(await cache.lookup(resolved: first, need: need))
        let late = await cache.lookup(resolved: second, need: need)

        guard case .overBudget = late else {
            Issue.record("not over budget: \(late)")
            return
        }
        #expect(pinned.image.width == 128)
        #expect(await cache.bytesHeld == limit)
    }

    private func sixteenBit(side: Int) -> CGImage? {
        let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 16, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context?.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return context?.makeImage()
    }

    @Test func aPictureDeeperThanTheEstimateIsNotDecodedAgainForNothing() async throws {
        let path = try png("deep.png", side: 1_024)
        let counter = DecodeCounter()
        let cache = CanvasImageCache(limit: bytes(longestSide: 128) * 3 / 2) { _, side in
            counter.note(side)
            return sixteenBit(side: side)
        }

        let first = try leased(await cache.lookup(resolved: path, need: need))
        let decodedFirst = counter.count
        let second = try leased(await cache.lookup(resolved: path, need: need))
        let third = try leased(await cache.lookup(resolved: path, need: need))

        #expect(first.image.width == 64)
        #expect(second.image.width == 64)
        #expect(third.image.width == 64)
        #expect(decodedFirst == 2)
        #expect(counter.count == decodedFirst)
    }

    @Test func aLeaseLetGoLetsThePictureBeEvicted() async throws {
        let first = try png("gone.png")
        let second = try png("after.png")
        let limit = bytes(longestSide: 128)
        let cache = CanvasImageCache(limit: limit)

        var pinned: CanvasImageLease? = try leased(await cache.lookup(resolved: first, need: need))
        #expect(pinned != nil)
        pinned = nil
        try await settled(cache)

        let next = try leased(await cache.lookup(resolved: second, need: need))
        #expect(next.image.width == 128)
    }

    @Test func aFileThatDoesNotDecodeIsAskedOnce() async throws {
        let url = folder.appending(path: "bad.svg")
        try Data("<svg".utf8).write(to: url)
        let counter = DecodeCounter()
        let cache = CanvasImageCache(decode: { _, side in
            counter.note(side)
            return nil
        })

        for _ in 0..<3 {
            guard case .unavailable = await cache.lookup(resolved: url.path, need: need) else {
                Issue.record("a picture from nothing")
                return
            }
        }
        #expect(counter.count == 1)
    }

    @Test func aLinkOrAMissingFileIsNotAPicture() async throws {
        let target = try png("target.png")
        let link = folder.appending(path: "link.png").path
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)
        let cache = CanvasImageCache()

        for path in [link, folder.appending(path: "absent.png").path] {
            guard case .unavailable = await cache.lookup(resolved: path, need: need) else {
                Issue.record("\(path) was admitted")
                return
            }
        }
    }

    @Test func aPictureOverThePixelLimitIsNeverDecoded() async throws {
        let path = try png("huge.png", side: 256)
        let counter = DecodeCounter()
        let cache = CanvasImageCache(maximumPixels: 100, decode: counting(counter))

        guard case .unavailable = await cache.lookup(resolved: path, need: need) else {
            Issue.record("the picture was admitted")
            return
        }
        #expect(counter.count == 0)
    }
}

@Suite("How many pixels an element needs of its picture")
struct CanvasImageNeedTests {
    private func side(_ width: Double, _ height: Double, ppp: Double = 1, source: (Int, Int)?) -> Int {
        CanvasImageNeed(width: width, height: height, pixelsPerPoint: ppp)
            .longestSide(ofSource: source.map { CanvasImagePixelSize(width: $0.0, height: $0.1) })
    }

    @Test func aSquarePictureIsCutToTheElementRoundedUpToAPowerOfTwo() {
        #expect(side(200, 200, source: (10_000, 10_000)) == 256)
    }

    @Test func aRetinaScreenAndZoomAskForMore() {
        #expect(side(200, 200, ppp: 2, source: (10_000, 10_000)) == 512)
        #expect(side(200, 200, ppp: 1.5, source: (10_000, 10_000)) == 512)
        #expect(side(200, 200, ppp: 3, source: (10_000, 10_000)) == 1_024)
    }

    @Test func aSmallZoomStaysAtOnePixelAPoint() {
        #expect(side(200, 200, ppp: 0.25, source: (10_000, 10_000)) == 256)
    }

    @Test func aWidePictureFillingASquareNeedsItsHeightToReachTheElement() {
        #expect(side(200, 200, source: (10_000, 100)) == CanvasImageNeed.longestSideCeiling)
        #expect(side(200, 200, source: (1_000, 100)) == 1_000)
    }

    @Test func aPictureIsNeverAskedToGrow() {
        #expect(side(1_000, 1_000, source: (300, 300)) == 300)
    }

    @Test func noPictureIsDecodedPastTheCeiling() {
        #expect(side(8_000, 8_000, ppp: 4, source: (10_000, 10_000)) == CanvasImageNeed.longestSideCeiling)
    }

    @Test func aVectorGetsTheSizeOfTheElement() {
        #expect(side(100, 300, ppp: 2, source: nil) == 1_024)
    }

    @Test func aPictureWithNoPixelsGetsTheSizeOfTheElementInsteadOfCrashing() {
        #expect(side(100, 300, ppp: 2, source: (0, 0)) == 1_024)
        #expect(side(100, 300, ppp: 2, source: (0, 50)) == 1_024)
    }
}
