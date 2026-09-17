import Foundation

public struct BrowserImageComment: Codable, Hashable, Sendable {
    public var body: String
    public var address: String

    public init(body: String, address: String) {
        self.body = body
        self.address = address
    }

    public static func expand(_ draft: String, comments: [String: BrowserImageComment]) -> String {
        AttachmentDraft.parse(draft, paths: Array(comments.keys)).segments.map { segment in
            guard case .attachment(let path) = segment, let comment = comments[path] else { return segment.text }
            return BrowserRegion.draft(comment: comment.body, address: comment.address, paths: [path])
        }.joined()
    }
}
