import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageDiffSide: Sendable, Equatable {
    case absent
    case tooLarge
    case image(Data)
}

public struct ImageDiffColumn: Sendable, Equatable {
    public let title: String?
    public let side: ImageDiffSide
}

public struct ImageDiffSides: Sendable, Equatable {
    public let before: ImageDiffSide
    public let after: ImageDiffSide

    public init(before: ImageDiffSide, after: ImageDiffSide) {
        self.before = before
        self.after = after
    }

    public var columns: [ImageDiffColumn] {
        switch (before, after) {
        case (.absent, .absent): []
        case (.absent, _): [ImageDiffColumn(title: nil, side: after)]
        case (_, .absent): [ImageDiffColumn(title: nil, side: before)]
        default: [ImageDiffColumn(title: "Before", side: before), ImageDiffColumn(title: "After", side: after)]
        }
    }
}

public enum ImageDiff {
    public static let sizeLimit = DocumentPreviewAnswer.sizeLimit
    public static let displayPixelLimit = 2_048
    public static let sourceAreaLimit = 100_000_000.0

    public static func isOffered(path: String, isBinary: Bool) -> Bool {
        guard isBinary, let type = UTType(filenameExtension: (path as NSString).pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    public static func decode(
        _ data: Data, pixelLimit: Int = displayPixelLimit, areaLimit: Double = sourceAreaLimit
    ) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              Double(width) * Double(height) <= areaLimit else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelLimit,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

extension Git {
    public static func imageSides(
        worktree: String, base: String, file: ChangedFile, scope: DiffScope = .all,
        limit: Int = ImageDiff.sizeLimit
    ) async -> ImageDiffSides {
        ImageDiffSides(
            before: await imageBefore(worktree: worktree, base: base, file: file, scope: scope, limit: limit),
            after: imageAfter(worktree: worktree, file: file, limit: limit)
        )
    }

    private static func imageBefore(
        worktree: String, base: String, file: ChangedFile, scope: DiffScope, limit: Int
    ) async -> ImageDiffSide {
        let path = file.oldPath ?? file.path
        let root = URL(filePath: worktree, directoryHint: .isDirectory)
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        guard file.change != .untracked,
              DocumentPreview.isOffered(resolvedRoot.appending(path: path), inside: root),
              let revision = try? await revision(for: scope, base: base, in: worktree) else { return .absent }
        let object = "\(revision):\(path)"
        guard let size = try? await run(["cat-file", "-s", object], in: worktree), size.ok,
              let bytes = Int(size.trimmed) else { return .absent }
        guard bytes <= limit else { return .tooLarge }
        guard let blob = try? await runRaw(["cat-file", "blob", object], in: worktree), blob.ok else {
            return .absent
        }
        return .image(blob.stdout)
    }

    private static func imageAfter(worktree: String, file: ChangedFile, limit: Int) -> ImageDiffSide {
        let root = URL(filePath: worktree, directoryHint: .isDirectory)
        guard let url = ContainedPath.resolve(root.appending(path: file.path), inside: root),
              DocumentPreview.isOffered(url, inside: root),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, let bytes = values.fileSize else { return .absent }
        guard bytes <= limit else { return .tooLarge }
        guard let data = try? Data(contentsOf: url) else { return .absent }
        return .image(data)
    }
}
