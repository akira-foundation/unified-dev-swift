import Foundation
import Core

struct PromptAttachment: Identifiable, Hashable, Codable, Sendable {
    var id: String = PromptAttachments.newShortID()
    var path: String
    var source: String = ""
    var isCopy: Bool
    var byteCount: Int = 0
    var imageComment: BrowserImageComment?

    var filename: String { (path as NSString).lastPathComponent }
    var directory: String { (path as NSString).deletingLastPathComponent }

    func url(in worktree: String) -> URL {
        URL(filePath: (worktree as NSString).appendingPathComponent(path))
    }

    static func sent(path: String) -> PromptAttachment {
        PromptAttachment(id: path, path: path, isCopy: false)
    }
}

enum AttachmentSource: Hashable, Sendable {
    case file(URL)
    case promisedFile(URL, PromisedAttachmentStorage)
    case image(Data, format: PastedImageFormat, named: String)
    case text(String, named: String)

    func named(_ name: String) -> AttachmentSource {
        switch self {
        case .file, .promisedFile: self
        case .image(let data, let format, _): .image(data, format: format, named: name)
        case .text(let body, _): .text(body, named: name)
        }
    }

    var filename: String {
        switch self {
        case .file(let url), .promisedFile(let url, _): url.lastPathComponent
        case .image(_, _, let name): name
        case .text(_, let name): name
        }
    }
}
