import AppKit
import Foundation
import Core

struct FeedbackImage: Identifiable, Equatable, Sendable {
    let id = UUID()
    var filename: String
    var contentType: String
    var data: Data

    var byteCount: Int { data.count }
}

enum FeedbackImages {
    enum Failure: LocalizedError, Equatable {
        case notAnImage(String)
        case unreadable(String)
        case tooLarge(String, Int)
        case tooMany
        case tooMuch

        var errorDescription: String? {
            switch self {
            case .notAnImage(let name): Feedback.notAnImageMessage(name: name)
            case .unreadable(let name): "Unified Dev could not read \(name)."
            case .tooLarge(let name, let bytes): Feedback.tooLargeMessage(name: name, bytes: bytes)
            case .tooMany: Feedback.tooManyMessage()
            case .tooMuch: Feedback.tooMuchMessage()
            }
        }
    }

    nonisolated static func read(
        _ sources: [AttachmentSource], existing: [FeedbackImage] = []
    ) throws -> [FeedbackImage] {
        guard existing.count + sources.count <= Feedback.maxImages else { throw Failure.tooMany }

        var found: [FeedbackImage] = []
        var total = existing.reduce(0) { $0 + $1.byteCount }

        for source in sources {
            let image = try read(source)
            guard image.byteCount <= Feedback.maxImageBytes else {
                throw Failure.tooLarge(image.filename, image.byteCount)
            }
            total += image.byteCount
            guard total <= Feedback.maxTotalImageBytes else { throw Failure.tooMuch }
            found.append(image)
        }
        return found
    }

    private nonisolated static func read(_ source: AttachmentSource) throws -> FeedbackImage {
        switch source {
        case .file(let url), .promisedFile(let url, _):
            return try read(file: url)
        case .image(let data, _, let name):
            guard let (bytes, type) = readable(data) else { throw Failure.notAnImage(name) }
            return FeedbackImage(filename: name, contentType: type, data: bytes)
        case .text(_, let name):
            throw Failure.notAnImage(name)
        }
    }

    private nonisolated static func read(file url: URL) throws -> FeedbackImage {
        let name = url.lastPathComponent

        let onDisk = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int ?? 0
        guard onDisk <= Feedback.maxImageBytes else { throw Failure.tooLarge(name, onDisk) }

        guard let data = try? Data(contentsOf: url), !data.isEmpty else { throw Failure.unreadable(name) }
        guard let (bytes, type) = readable(data) else { throw Failure.notAnImage(name) }

        return FeedbackImage(filename: name, contentType: type, data: bytes)
    }

    private nonisolated static func readable(_ data: Data) -> (Data, String)? {
        if let sniffed = Feedback.sniffedContentType(data) { return (data, sniffed) }

        guard let representation = NSBitmapImageRep(data: data),
              let png = representation.representation(using: .png, properties: [:]),
              Feedback.sniffedContentType(png) == "image/png"
        else { return nil }

        return (png, "image/png")
    }
}
