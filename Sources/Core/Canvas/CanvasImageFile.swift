import Darwin
import Foundation
import ImageIO

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

    private static func pixelCount(of path: String) -> Int? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let (pixels, overflowed) = width.multipliedReportingOverflow(by: height)
        return overflowed ? Int.max : pixels
    }
}
