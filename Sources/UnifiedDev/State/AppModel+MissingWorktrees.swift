import Core
import Foundation

extension AppModel {
    func noteMissingWorktrees(exempt: Set<WorkspaceID>) async {
        let snapshot = workspaces
        let present = await Self.foldersOnDisk(snapshot.map(\.path))
        let missing = missingWorktrees.newlyMissing(among: snapshot, exempt: exempt) { present.contains($0) }
        for workspace in missing {
            Log.archive.error("the folder of \(workspace.name, privacy: .public) is gone")
        }
        if let notice = missingWorktrees.noticeToShow(slotIsFree: notice == nil) { self.notice = notice }
    }

    private nonisolated static func foldersOnDisk(_ paths: [String]) async -> Set<String> {
        Set(paths.filter { FileManager.default.fileExists(atPath: $0) })
    }
}
