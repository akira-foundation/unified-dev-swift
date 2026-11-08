import CoreGraphics
import Foundation

public struct CanvasRenderPictures {
    public typealias Decoder = (_ path: String, _ longestSide: Int) -> CGImage?

    public static let byteLimit = 256 * 1_024 * 1_024

    private struct Held {
        let side: Int
        let image: CGImage
        let bytes: Int
    }

    private let documentPath: String
    private let worktree: String
    private let pixelsPerPoint: Double
    private let limit: Int
    private let decode: Decoder
    private var held: [String: Held] = [:]
    public private(set) var bytesHeld = 0
    public private(set) var skipped: [String] = []

    public init(
        documentPath: String, worktree: String, pixelsPerPoint: Double, limit: Int = byteLimit,
        decode: @escaping Decoder = { CanvasImageFile.decoded($0, longestSide: $1) }
    ) {
        self.documentPath = documentPath
        self.worktree = worktree
        self.pixelsPerPoint = pixelsPerPoint
        self.limit = limit
        self.decode = decode
    }

    public mutating func image(_ relative: String, size: CanvasSize) -> CGImage? {
        guard let path = CanvasImagePath.resolve(relative, beside: documentPath, worktree: worktree),
              CanvasImageFile.admits(path) else { return nil }
        let source = CanvasImageFile.pixelSize(of: path)
        let side = CanvasImageNeed(width: size.width, height: size.height, pixelsPerPoint: pixelsPerPoint).longestSide(ofSource: source)
        let previous = held[path]
        if let previous, previous.side >= side { return previous.image }
        let freed = previous?.bytes ?? 0
        guard bytesHeld - freed + CanvasImageNeed.estimatedBytes(of: source, longestSide: side) <= limit else { return skipping(relative, keeping: previous) }
        guard let image = decode(path, side) else { return previous?.image }
        let bytes = image.bytesPerRow * image.height
        guard bytesHeld - freed + bytes <= limit else { return skipping(relative, keeping: previous) }
        bytesHeld += bytes - freed
        held[path] = Held(side: side, image: image, bytes: bytes)
        return image
    }

    private mutating func skipping(_ relative: String, keeping previous: Held?) -> CGImage? {
        guard let previous else {
            if !skipped.contains(relative) { skipped.append(relative) }
            return nil
        }
        return previous.image
    }
}
