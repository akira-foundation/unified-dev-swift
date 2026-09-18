import Foundation
import Core

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

    static func handOver(draftID: String, into worktree: String) {
        let staging = directory(draftID: draftID)
        let files = (FileManager.default.subpaths(atPath: staging) ?? []).filter { path in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: (staging as NSString).appendingPathComponent(path), isDirectory: &isDirectory
            )
            return exists && !isDirectory.boolValue
        }
        WorkspaceStartAttachments.adopt(files, from: staging, into: worktree)
        discard(draftID: draftID)
    }
}
