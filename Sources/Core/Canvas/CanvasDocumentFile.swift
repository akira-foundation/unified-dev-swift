import Foundation

public enum CanvasDocumentFile {
    public static let fileExtension = "udcanvas"

    public static let folder = "canvases"

    public static func isDocument(path: String) -> Bool {
        (path as NSString).pathExtension.lowercased() == fileExtension
    }

    public static func read(at absolute: String) throws -> CanvasDocumentDecoding {
        CanvasDocumentCodec.decode(try Data(contentsOf: URL(filePath: absolute)))
    }

    @discardableResult
    public static func write(_ document: CanvasDocument, to absolute: String) throws -> Data {
        let data = try CanvasDocumentCodec.encode(document)
        try data.write(to: URL(filePath: absolute), options: .atomic)
        return data
    }

    public static func bytes(at absolute: String) throws -> Data? {
        do {
            return try Data(contentsOf: URL(filePath: absolute))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    public static func writeBackup(_ data: Data, beside absolute: String, at date: Date) throws -> String {
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
        return "\(absolute).backup-\(stamp)"
    }

    static func blank() -> CanvasDocument {
        CanvasDocument(frames: [
            CanvasFrame(name: "Slide 1", rect: CanvasRect(x: 0, y: 0, width: 1080, height: 1350), fill: "#FFFFFF", revision: 0),
        ])
    }
}
