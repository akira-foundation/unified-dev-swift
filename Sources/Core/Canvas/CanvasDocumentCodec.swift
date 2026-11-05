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

    public static func encode(_ document: CanvasDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }
}
