import Foundation

public enum CanvasDocumentDecoding: Sendable, Equatable {
    case document(CanvasDocument)
    case corrupt(String)
    case newerVersion(Int)
}

public enum CanvasDocumentCodec {
    private struct VersionProbe: Decodable {
        let version: Int
    }

    public static func decode(_ data: Data) -> CanvasDocumentDecoding {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let probe = try decoder.decode(VersionProbe.self, from: data)
            guard probe.version <= CanvasDocument.currentVersion else {
                return .newerVersion(probe.version)
            }
            return .document(try decoder.decode(CanvasDocument.self, from: data))
        } catch {
            return .corrupt(String(describing: error))
        }
    }

    public static func encodeForDisk(_ document: CanvasDocument, limit: Int = CanvasDocumentFile.maximumBytes) throws -> Data {
        let pretty = try encode(document)
        guard pretty.count > limit else { return pretty }
        let compact = try encode(document, formatting: [.sortedKeys, .withoutEscapingSlashes])
        guard compact.count <= limit else { throw CanvasDocumentFile.TooLarge(size: compact.count) }
        return compact
    }

    public static func encode(_ document: CanvasDocument) throws -> Data {
        try encode(document, formatting: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    private static func encode(_ document: CanvasDocument, formatting: JSONEncoder.OutputFormatting) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = formatting
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }
}
