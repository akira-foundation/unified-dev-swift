import Foundation

public enum CanvasExportRefusal: Error, Sendable, Equatable {
    case documentOutsideWorktree
    case noFrames
    case directoryIsSymbolicLink(String)
    case directoryIsNotAFolder(String)
    case directoryOutsideWorktree(String)
    case directoryMoved(String)

    public var sentence: String {
        switch self {
        case .documentOutsideWorktree:
            "This canvas is not inside the workspace, so nothing was exported."
        case .noFrames:
            "This canvas has no frames to export."
        case .directoryIsSymbolicLink(let name):
            "\(name) is a symbolic link, and an export never writes through one. Remove it or move it away, then export again."
        case .directoryIsNotAFolder(let name):
            "\(name) exists and is not a folder, so nothing was exported."
        case .directoryOutsideWorktree(let name):
            "\(name) would be outside the workspace, so nothing was exported."
        case .directoryMoved(let name):
            "The folder holding \(name) changed while the export was running, so nothing was written. Export again."
        }
    }
}

extension CanvasExportRefusal: LocalizedError {
    public var errorDescription: String? { sentence }
}

public struct CanvasExportSlide: Sendable, Equatable {
    public var frame: CanvasFrame
    public var file: String
}

public struct CanvasExportPlan: Sendable, Equatable {
    public let directory: String
    public let slides: [CanvasExportSlide]
    public let refused: [CanvasExportFailure]

    public static func make(document: CanvasDocument, path: String, worktree: String) throws -> CanvasExportPlan {
        guard case .file(let absolute, _) = CanvasFile.contained(path: path, worktree: worktree) else {
            throw CanvasExportRefusal.documentOutsideWorktree
        }
        guard !document.frames.isEmpty else { throw CanvasExportRefusal.noFrames }
        let name = CanvasExportNames.directoryName(forDocumentAt: absolute)
        let parent = URL(filePath: (absolute as NSString).deletingLastPathComponent, directoryHint: .isDirectory)
        let root = URL(filePath: worktree, directoryHint: .isDirectory)
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let contained = ContainedPath.resolve(parent, inside: root)
            ?? (parent.standardizedFileURL.resolvingSymlinksInPath() == resolvedRoot ? resolvedRoot : nil)
        guard let contained else { throw CanvasExportRefusal.directoryOutsideWorktree(name) }
        let directory = URL(filePath: Self.realPath(contained.path), directoryHint: .isDirectory).appending(path: name, directoryHint: .isDirectory).path
        try checkDirectory(directory, named: name)

        let documentName = ((absolute as NSString).lastPathComponent as NSString).deletingPathExtension
        let files = CanvasExportNames.files(for: document.frames, document: documentName)
        var slides: [CanvasExportSlide] = []
        var refused: [CanvasExportFailure] = []
        for frame in CanvasExportNames.slideOrder(document.frames) {
            guard let file = files[frame.id] else { continue }
            guard CanvasRenderPlan(frameSize: frame.rect.size) != nil else {
                refused.append(CanvasExportFailure(frame: frame.name, reason: refusalSentence(for: frame)))
                continue
            }
            slides.append(CanvasExportSlide(frame: frame, file: file))
        }
        return CanvasExportPlan(directory: directory, slides: slides, refused: refused)
    }

    public static func realPath(_ path: String) -> String {
        CanvasExportDirectory.canonicalPath(of: path) ?? path
    }

    public func checkDirectory() throws {
        try Self.checkDirectory(directory, named: (directory as NSString).lastPathComponent)
    }

    public static func missingImages(
        in frame: CanvasFrame, of document: CanvasDocument, documentPath: String, worktree: String,
        draws: (String) -> Bool
    ) -> [String] {
        var seen: Set<String> = []
        return document.elements.filter { $0.frameID == frame.id }.compactMap { element -> String? in
            guard case .image(let path) = element.kind, seen.insert(path).inserted else { return nil }
            guard let resolved = CanvasImagePath.resolve(path, beside: documentPath, worktree: worktree) else { return path }
            return draws(resolved) ? nil : path
        }
    }

    private static func checkDirectory(_ directory: String, named name: String) throws {
        guard let type = try? FileManager.default.attributesOfItem(atPath: directory)[.type] as? FileAttributeType else { return }
        switch type {
        case .typeDirectory: return
        case .typeSymbolicLink: throw CanvasExportRefusal.directoryIsSymbolicLink(name)
        default: throw CanvasExportRefusal.directoryIsNotAFolder(name)
        }
    }

    private static func refusalSentence(for frame: CanvasFrame) -> String {
        let size = frame.rect.size
        let limit = CanvasRenderPlan.points(CanvasFrameSize.maximum)
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            return "its size is not a size a picture can have."
        }
        return "it is \(CanvasRenderPlan.points(size.width)) by \(CanvasRenderPlan.points(size.height)) points, and an export draws up to \(limit) points a side."
    }
}
