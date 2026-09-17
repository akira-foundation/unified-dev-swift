import Foundation
import AppKit
import Core

enum AttachmentFiles {
    static let maxByteCount = 100 * 1024 * 1024

    static let maxPastedByteCount = 1024 * 1024 * 1024

    enum Failure: LocalizedError {
        case unreadable(String)
        case tooLarge(String, Int)
        case tooLargeToPaste(String, Int)
        case copyFailed(String, String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name):
                "Unified Dev could not read \(name)."
            case .tooLarge(let name, let bytes):
                """
                \(name) is \(Self.size(bytes)), and an attachment is copied into the worktree. \
                Mention it with @ instead, or move it into the worktree yourself.
                """
            case .tooLargeToPaste(let name, let bytes):
                """
                That image is \(Self.size(bytes)), which is more than Unified Dev will write into a \
                worktree (\(Self.size(maxByteCount))). Save it to a file and attach that, or \
                paste a smaller one. It would have been written as \(name).
                """
            case .copyFailed(let name, let reason):
                "\(name) could not be copied into the worktree. \(reason)"
            }
        }

        private static func size(_ bytes: Int) -> String {
            ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        }
    }

    static func attach(_ source: AttachmentSource, workspace: String) throws -> PromptAttachment {
        switch source {
        case .file(let url), .promisedFile(let url, _):
            try attach(file: url, workspace: workspace)
        case .image(let data, let format, let name):
            try attach(image: data, format: format, named: name, workspace: workspace)
        case .text(let body, let name):
            try attach(bytes: Data(body.utf8), named: name, workspace: workspace)
        }
    }

    private static func attach(
        bytes: Data, named name: String, workspace: String
    ) throws -> PromptAttachment {
        let id = PromptAttachments.newShortID()
        let relative = PromptAttachments.destination(filename: name, id: id)
        let destination = URL(filePath: (workspace as NSString).appendingPathComponent(relative))

        do {
            try prepare(destination, in: workspace)
            try bytes.write(to: destination, options: .atomic)
        } catch {
            throw Failure.copyFailed(name, error.localizedDescription)
        }

        return PromptAttachment(id: id, path: relative, isCopy: true, byteCount: bytes.count)
    }

    private static func attach(file url: URL, workspace: String) throws -> PromptAttachment {
        let path = url.standardizedFileURL.path
        let name = url.lastPathComponent

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              FileManager.default.isReadableFile(atPath: path) else {
            throw Failure.unreadable(name)
        }
        guard !isDirectory.boolValue else { throw Failure.unreadable(name) }

        let bytes = byteCount(of: path)

        if let relative = relativePath(of: path, in: workspace) {
            return PromptAttachment(path: relative, source: path, isCopy: false, byteCount: bytes)
        }

        guard bytes <= maxByteCount else { throw Failure.tooLarge(name, bytes) }

        let id = PromptAttachments.newShortID()
        let relative = PromptAttachments.destination(filename: name, id: id)
        let destination = URL(filePath: (workspace as NSString).appendingPathComponent(relative))

        do {
            try prepare(destination, in: workspace)
            try FileManager.default.copyItem(at: URL(filePath: path), to: destination)
        } catch {
            throw Failure.copyFailed(name, error.localizedDescription)
        }

        return PromptAttachment(
            id: id, path: relative, source: path, isCopy: true, byteCount: bytes
        )
    }

    private static func attach(
        image pasted: Data, format: PastedImageFormat, named name: String, workspace: String
    ) throws -> PromptAttachment {
        guard pasted.count <= maxPastedByteCount else {
            throw Failure.tooLargeToPaste(name, pasted.count)
        }

        let (data, filename) = readable(pasted, format: format, named: name)

        guard data.count <= maxByteCount else { throw Failure.tooLargeToPaste(filename, data.count) }

        let id = PromptAttachments.newShortID()
        let relative = PromptAttachments.destination(filename: filename, id: id)
        let destination = URL(filePath: (workspace as NSString).appendingPathComponent(relative))

        do {
            try prepare(destination, in: workspace)
            try data.write(to: destination, options: .atomic)
        } catch {
            throw Failure.copyFailed(filename, error.localizedDescription)
        }

        return PromptAttachment(path: relative, isCopy: true, byteCount: data.count)
    }

    private static func readable(
        _ data: Data, format: PastedImageFormat, named name: String
    ) -> (Data, String) {
        guard format.isWorthReencoding else { return (data, name) }

        guard let representation = NSBitmapImageRep(data: data),
              let png = representation.representation(using: .png, properties: [:]) else {
            let base = (name as NSString).deletingPathExtension
            return (data, "\(base).\(format.fileExtension)")
        }
        return (png, name)
    }

    static func discard(_ attachment: PromptAttachment, workspace: String) {
        guard attachment.isCopy else { return }
        let file = attachment.url(in: workspace)
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }

    private static func prepare(_ destination: URL, in workspace: String) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        shield(workspace: workspace)
    }

    static func shield(workspace: String) {
        WorktreeScratch.shield(WorktreeScratch.attachments, in: workspace)
    }

    static func relativePath(of path: String, in workspace: String) -> String? {
        let file = URL(filePath: path).resolvingSymlinksInPath().path
        let root = URL(filePath: workspace).resolvingSymlinksInPath().path
        guard file.hasPrefix(root + "/") else { return nil }
        return String(file.dropFirst(root.count + 1))
    }

    static func byteCount(of path: String) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int ?? 0
    }
}
