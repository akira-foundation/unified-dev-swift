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
            return .corrupt(unreadable(because: error))
        }
    }

    private static func unreadable(because error: Error) -> String {
        let sentence = "The file could not be read as a canvas."
        let path = codingPath(of: error).map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        return path.isEmpty ? sentence : "\(sentence) The problem is at \(path)."
    }

    private static func codingPath(of error: Error) -> [any CodingKey] {
        switch error as? DecodingError {
        case .keyNotFound(let key, let context): context.codingPath + [key]
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context): context.codingPath
        case .none: []
        @unknown default: []
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
        let encoder = encoder()
        encoder.outputFormatting = formatting
        return try encoder.encode(document)
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
