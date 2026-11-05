import Foundation

public enum CanvasImageImport {
    public static let fallbackSize = CanvasSize(width: 400, height: 400)
    private static let frameShare = 0.8

    public struct FolderIsLink: LocalizedError, Equatable {
        public let name: String

        public var errorDescription: String? {
            "\(name) is a symbolic link, so nothing was copied through it. Move it away and add the image again."
        }
    }

    public static func destination(for source: String, beside document: String, existing: Set<String>) -> String {
        let folder = URL(filePath: document).deletingPathExtension().lastPathComponent + ".assets"
        let name = URL(filePath: source).lastPathComponent
        let stem = (name as NSString).deletingPathExtension
        let suffix = (name as NSString).pathExtension.isEmpty ? "" : "." + (name as NSString).pathExtension
        var candidate = "\(folder)/\(name)"
        var counter = 2
        while existing.contains(candidate) {
            candidate = "\(folder)/\(stem) \(counter)\(suffix)"
            counter += 1
        }
        return candidate
    }

    public static func copy(_ source: String, beside document: String) throws -> String {
        let directory = URL(filePath: document).deletingLastPathComponent()
        let folder = directory.appending(path: URL(filePath: document).deletingPathExtension().lastPathComponent + ".assets")
        guard (try? FileManager.default.destinationOfSymbolicLink(atPath: folder.path)) == nil else {
            throw FolderIsLink(name: folder.lastPathComponent)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let present = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        let existing = Set(present.map { folder.lastPathComponent + "/" + $0 })
        let relative = destination(for: source, beside: document, existing: existing)
        try FileManager.default.copyItem(atPath: source, toPath: directory.appending(path: relative).path)
        return relative
    }

    public static func fittedSize(of image: CanvasSize, in frame: CanvasSize) -> CanvasSize {
        guard image.width > 0, image.height > 0 else { return fallbackSize }
        let scale = min(1, frame.width * frameShare / image.width, frame.height * frameShare / image.height)
        return CanvasSize(width: image.width * scale, height: image.height * scale)
    }
}
