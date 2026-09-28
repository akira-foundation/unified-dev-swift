import Foundation

public struct DocumentPreviewAnswer: Sendable, Equatable {
    public var status: Int
    public var type: String
    public var body: Data

    public init(status: Int, type: String, body: Data) {
        self.status = status
        self.type = type
        self.body = body
    }

    public static let refused = DocumentPreviewAnswer(
        status: 403, type: "text/plain; charset=utf-8", body: Data("Outside this preview".utf8)
    )

    public static let sizeLimit = 16 * 1_048_576

    public static let tooLarge = DocumentPreviewAnswer(
        status: 413, type: "text/plain; charset=utf-8", body: Data("Too large for this preview".utf8)
    )

    public static func read(_ file: URL, draft: String?) -> DocumentPreviewAnswer {
        let type = DocumentPreview.contentType(forFile: file.path)
        if let draft {
            return DocumentPreviewAnswer(status: 200, type: type, body: Data(draft.utf8))
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)??.intValue
        if let size, size > sizeLimit { return tooLarge }
        do {
            let body = try Data(contentsOf: file, options: .mappedIfSafe)
            return DocumentPreviewAnswer(status: 200, type: type, body: body)
        } catch {
            return DocumentPreviewAnswer(
                status: 404, type: "text/plain; charset=utf-8", body: Data(error.localizedDescription.utf8)
            )
        }
    }
}
