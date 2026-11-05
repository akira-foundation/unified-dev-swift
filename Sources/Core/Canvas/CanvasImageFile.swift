import Darwin
import Foundation
import CoreGraphics
import ImageIO

public struct CanvasImagePixelSize: Sendable, Equatable {
    public let width: Int
    public let height: Int

    var longestSide: Int { max(width, height) }
}

struct CanvasImageFileStamp: Sendable, Hashable {
    let path: String
    let seconds: Int
    let nanoseconds: Int
    let bytes: Int
}

public enum CanvasImageFile {
    public static let maximumBytes = 64 * 1_024 * 1_024
    public static let maximumPixels = 100_000_000
    private static let vectorExtensions: Set<String> = ["svg", "pdf"]

    public static func admits(_ path: String, maximumBytes: Int = maximumBytes, maximumPixels: Int = maximumPixels) -> Bool {
        var status = stat()
        guard lstat(path, &status) == 0, status.st_mode & S_IFMT == S_IFREG, status.st_size <= maximumBytes else { return false }
        guard let pixels = pixelCount(of: path) else {
            return vectorExtensions.contains((path as NSString).pathExtension.lowercased())
        }
        return pixels <= maximumPixels
    }

    static func stamp(of path: String, maximumBytes: Int = maximumBytes) -> CanvasImageFileStamp? {
        var status = stat()
        guard lstat(path, &status) == 0, status.st_mode & S_IFMT == S_IFREG, status.st_size <= maximumBytes else { return nil }
        return CanvasImageFileStamp(
            path: path, seconds: status.st_mtimespec.tv_sec, nanoseconds: status.st_mtimespec.tv_nsec, bytes: Int(status.st_size)
        )
    }

    public static func pixelSize(of path: String) -> CanvasImagePixelSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let isTurned = (properties[kCGImagePropertyOrientation] as? Int ?? 1) >= 5
        return isTurned ? CanvasImagePixelSize(width: height, height: width) : CanvasImagePixelSize(width: width, height: height)
    }

    public static func decoded(_ path: String, longestSide: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func pixelCount(of path: String) -> Int? {
        guard let size = pixelSize(of: path) else { return nil }
        let (pixels, overflowed) = size.width.multipliedReportingOverflow(by: size.height)
        return overflowed ? Int.max : pixels
    }
}
