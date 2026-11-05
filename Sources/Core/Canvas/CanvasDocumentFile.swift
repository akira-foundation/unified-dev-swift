import Darwin
import Foundation

public enum CanvasDocumentFile {
    public static let fileExtension = "udcanvas"

    public static let folder = "canvases"

    public static let maximumBytes = 64 * 1_024 * 1_024

    public static func isDocument(path: String) -> Bool {
        (path as NSString).pathExtension.lowercased() == fileExtension
    }

    public static func read(at absolute: String) throws -> CanvasDocumentDecoding {
        guard let data = try bytes(at: absolute) else { throw CocoaError(.fileReadNoSuchFile) }
        return CanvasDocumentCodec.decode(data)
    }

    @discardableResult
    public static func write(_ document: CanvasDocument, to absolute: String) throws -> Data {
        let data = try CanvasDocumentCodec.encodeForDisk(document)
        try data.write(to: URL(filePath: absolute), options: .atomic)
        return data
    }

    public struct TooLarge: LocalizedError, Equatable {
        public let size: Int

        public var megabytes: Int { (size + 1_048_575) / 1_048_576 }

        public var errorDescription: String? {
            "This canvas file is \(megabytes) MB, more than the \(CanvasDocumentFile.limitInMegabytes) MB Unified Dev opens, so it was left as it is."
        }
    }

    public struct NotAFile: LocalizedError, Equatable {
        public var errorDescription: String? { "This canvas is not a regular file, so it was left as it is." }
    }

    public struct IsLink: LocalizedError, Equatable {
        public init() {}

        public var errorDescription: String? {
            "This canvas has become a symbolic link, so it was not followed and was left as it is. Move the link away to carry on."
        }
    }

    public static var limitInMegabytes: Int { maximumBytes / 1_048_576 }

    public static func bytes(at absolute: String) throws -> Data? {
        try bytes(at: absolute, limit: maximumBytes, afterMeasuring: {})
    }

    static func bytes(at absolute: String, limit: Int, afterMeasuring: () throws -> Void) throws -> Data? {
        let descriptor = Darwin.open(absolute, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            if errno == ENOENT { return nil }
            if errno == ELOOP { throw IsLink() }
            throw lastError()
        }
        defer { Darwin.close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { throw lastError() }
        guard status.st_mode & S_IFMT == S_IFREG else { throw NotAFile() }
        guard status.st_size <= limit else { throw TooLarge(size: Int(status.st_size)) }
        try afterMeasuring()
        return try contents(of: descriptor, upTo: limit)
    }

    private static func contents(of descriptor: Int32, upTo limit: Int) throws -> Data {
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 1_048_576)
        while true {
            let count = Darwin.read(descriptor, &chunk, min(chunk.count, limit + 1 - data.count))
            if count == 0 { return data }
            if count < 0 {
                if errno == EINTR { continue }
                throw lastError()
            }
            data.append(chunk, count: count)
            guard data.count <= limit else { throw TooLarge(size: data.count) }
        }
    }

    private static func lastError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    public static func writeBackup(_ data: Data, beside absolute: String, at date: Date) throws -> String {
        guard data.count <= maximumBytes else { throw TooLarge(size: data.count) }
        var moment = date
        var path = backupPath(for: absolute, at: moment)
        while FileManager.default.fileExists(atPath: path) {
            moment.addTimeInterval(1)
            path = backupPath(for: absolute, at: moment)
        }
        try data.write(to: URL(filePath: path), options: .atomic)
        return path
    }

    public static func nextName(in existing: Set<String>) -> String {
        var candidate = "\(folder)/canvas.\(fileExtension)"
        var number = 2
        while existing.contains(candidate) {
            candidate = "\(folder)/canvas-\(number).\(fileExtension)"
            number += 1
        }
        return candidate
    }

    public static func backupPath(for absolute: String, at date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        let stamp = formatter.string(from: date)
        let stem = (absolute as NSString).deletingPathExtension
        return "\(stem).backup-\(stamp).\(fileExtension)"
    }

    static func blank() -> CanvasDocument {
        CanvasDocument(frames: [
            CanvasFrame(name: "Slide 1", rect: CanvasRect(x: 0, y: 0, width: 1080, height: 1350), fill: "#FFFFFF", revision: 0),
        ])
    }
}
