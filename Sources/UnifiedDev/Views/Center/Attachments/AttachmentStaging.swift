import Foundation

struct StagedAttachments: Sendable {
    var directory: String
    var attachments: [PromptAttachment]
}

enum AttachmentStaging {
    static func directory(draftID: String) -> String {
        let root = (NSTemporaryDirectory() as NSString).appendingPathComponent("unifieddev-drafts")
        return (root as NSString).appendingPathComponent(draftID)
    }

    static func discard(draftID: String) {
        try? FileManager.default.removeItem(atPath: directory(draftID: draftID))
    }
}
