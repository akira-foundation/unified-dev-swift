import Foundation

public enum WorkspaceStartAttachments {
    public static func handover(isChatWorkspace: Bool, draft: String, name: String) -> String {
        (isChatWorkspace ? draft : name).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func spoken(_ handedOver: String, staged: [String]) -> String {
        AttachmentDraft.withoutAttachments(handedOver, paths: staged)
    }

    public static func opening(
        _ handedOver: String, staged: [String], arrived: Set<String>, isChatWorkspace: Bool
    ) -> String? {
        guard isChatWorkspace else { return nil }
        guard !staged.isEmpty else { return handedOver }
        return AttachmentDraft.parse(handedOver, paths: staged).keeping { arrived.contains($0) }
    }

    @discardableResult
    public static func adopt(
        _ paths: [String], from staging: String, into worktree: String
    ) -> Set<String> {
        guard !paths.isEmpty else { return [] }
        WorktreeScratch.shield(WorktreeScratch.attachments, in: worktree)

        let manager = FileManager.default
        var arrived: Set<String> = []
        for path in paths {
            let from = URL(filePath: (staging as NSString).appendingPathComponent(path))
            let destination = URL(filePath: (worktree as NSString).appendingPathComponent(path))
            guard manager.fileExists(atPath: from.path) else { continue }
            do {
                try manager.createDirectory(
                    at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try manager.moveItem(at: from, to: destination)
                arrived.insert(path)
            } catch {
                continue
            }
        }
        return arrived
    }
}
