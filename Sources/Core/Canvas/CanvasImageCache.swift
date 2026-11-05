import CoreGraphics
import Dispatch
import Foundation

public final class CanvasImageLease: Sendable {
    public let image: CGImage
    fileprivate let key: CanvasImageCache.Key
    private let cache: CanvasImageCache

    fileprivate init(image: CGImage, key: CanvasImageCache.Key, cache: CanvasImageCache) {
        self.image = image
        self.key = key
        self.cache = cache
    }

    public func isSamePicture(as other: CanvasImageLease?) -> Bool {
        key == other?.key
    }

    deinit {
        Task { [cache, key] in await cache.release(key) }
    }
}

public enum CanvasImageLookup: Sendable {
    case ready(CanvasImageLease)
    case unavailable
    case overBudget
}

public actor CanvasImageCache {
    public typealias Decoder = @Sendable (_ path: String, _ longestSide: Int) -> CGImage?

    public static let defaultLimit = 256 * 1_024 * 1_024
    private static let smallestSide = 64
    private static let bytesPerPixel = 4
    private static let longestFactsList = 1_024

    fileprivate struct Key: Hashable, Sendable {
        let stamp: CanvasImageFileStamp
        let side: Int
    }

    private struct Facts {
        let size: CanvasImagePixelSize?
        var isAdmitted: Bool
    }

    private let queue = DispatchSerialQueue(label: "io.akira.unifieddev.canvas-images", qos: .userInitiated)
    private let decode: Decoder
    private let maximumPixels: Int
    private var budget: CanvasImageBudget<Key, CGImage>
    private var facts: [CanvasImageFileStamp: Facts] = [:]

    public nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    public init(
        limit: Int = defaultLimit,
        maximumPixels: Int = CanvasImageFile.maximumPixels,
        decode: @escaping Decoder = { CanvasImageFile.decoded($0, longestSide: $1) }
    ) {
        budget = CanvasImageBudget(limit: limit)
        self.maximumPixels = maximumPixels
        self.decode = decode
    }

    var bytesHeld: Int { budget.bytesHeld }
    var leasesHeld: Int { budget.leasesHeld }

    public func lookup(_ relative: String, documentPath: String, worktree: String, need: CanvasImageNeed) -> CanvasImageLookup {
        guard !Task.isCancelled,
              let resolved = CanvasImagePath.resolve(relative, beside: documentPath, worktree: worktree) else { return .unavailable }
        return lookup(resolved: resolved, need: need)
    }

    func lookup(resolved path: String, need: CanvasImageNeed) -> CanvasImageLookup {
        guard let stamp = CanvasImageFile.stamp(of: path) else { return .unavailable }
        let known = facts(of: stamp)
        guard known.isAdmitted else { return .unavailable }
        var side = need.longestSide(ofSource: known.size)
        repeat {
            if let held = budget.firstKey(where: { $0.stamp == stamp && $0.side >= side }) { return lease(held) }
            if budget.makeRoom(for: Self.estimatedBytes(of: known.size, longestSide: side)) {
                guard let image = decode(path, side) else {
                    facts[stamp]?.isAdmitted = false
                    return .unavailable
                }
                let bytes = image.bytesPerRow * image.height
                if budget.makeRoom(for: bytes) {
                    let key = Key(stamp: stamp, side: side)
                    budget.add(image, bytes: bytes, for: key)
                    return lease(key)
                }
            }
            side /= 2
        } while side >= Self.smallestSide
        return .overBudget
    }

    fileprivate func release(_ key: Key) {
        budget.release(key)
    }

    private func lease(_ key: Key) -> CanvasImageLookup {
        guard let image = budget.lease(key) else { return .unavailable }
        return .ready(CanvasImageLease(image: image, key: key, cache: self))
    }

    private func facts(of stamp: CanvasImageFileStamp) -> Facts {
        if let known = facts[stamp] { return known }
        if facts.count >= Self.longestFactsList { facts.removeAll() }
        let found = Facts(size: CanvasImageFile.pixelSize(of: stamp.path), isAdmitted: CanvasImageFile.admits(stamp.path, maximumPixels: maximumPixels))
        facts[stamp] = found
        return found
    }

    private static func estimatedBytes(of size: CanvasImagePixelSize?, longestSide: Int) -> Int {
        guard let size, size.longestSide > 0 else { return longestSide * longestSide * bytesPerPixel }
        let shortest = min(size.width, size.height) * longestSide / size.longestSide
        return longestSide * max(shortest, 1) * bytesPerPixel
    }
}
