import Foundation

struct CanvasExportManifest: Codable, Sendable, Equatable {
    static let fileName = ".export-manifest.json"
    static let largestBytes = 1_048_576

    private var documents: [String: [String]] = [:]

    init() {}

    init(reading data: Data?) {
        guard let data, let read = try? JSONDecoder().decode(Self.self, from: data) else { return }
        self = read
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    func files(of document: String) -> Set<String> {
        Set(documents[document] ?? [])
    }

    func removable(for document: String, keeping current: Set<String>) -> Set<String> {
        let claimedElsewhere = documents.filter { $0.key != document }.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        return files(of: document).subtracting(current).subtracting(claimedElsewhere)
    }

    mutating func record(_ files: Set<String>, for document: String) {
        documents[document] = files.sorted()
    }
}
