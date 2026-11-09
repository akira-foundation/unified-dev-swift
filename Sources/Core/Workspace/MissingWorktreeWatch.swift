import Foundation

public struct MissingWorktreeWatch: Sendable {
    private var seenOnDisk: Set<WorkspaceID> = []
    private var absentOnce: Set<WorkspaceID> = []
    private var undelivered: [Workspace] = []

    public init() {}

    public mutating func newlyMissing(
        among workspaces: [Workspace],
        exempt: Set<WorkspaceID> = [],
        exists: (String) -> Bool
    ) -> [Workspace] {
        let watched = workspaces.filter { $0.state == .active && !exempt.contains($0.id) }
        let watchedIDs = Set(watched.map(\.id))
        absentOnce.formIntersection(watchedIDs)
        seenOnDisk.formIntersection(watchedIDs.union(exempt))
        undelivered.removeAll { !watchedIDs.contains($0.id) }

        var missing: [Workspace] = []
        for workspace in watched {
            guard !exists(workspace.path) else {
                seenOnDisk.insert(workspace.id)
                absentOnce.remove(workspace.id)
                undelivered.removeAll { $0.id == workspace.id }
                continue
            }
            guard seenOnDisk.contains(workspace.id), !absentOnce.insert(workspace.id).inserted else { continue }
            seenOnDisk.remove(workspace.id)
            missing.append(workspace)
        }
        undelivered.append(contentsOf: missing)
        return missing
    }

    public mutating func noticeToShow(slotIsFree: Bool) -> Notice? {
        guard slotIsFree, let notice = Self.notice(for: undelivered) else { return nil }
        undelivered = []
        return notice
    }

    static func notice(for missing: [Workspace]) -> Notice? {
        guard let first = missing.first else { return nil }
        let message = missing.count == 1
            ? "The folder of `\(first.name)` is not on disk any more, so git and the agents cannot work there. "
                + "Restore it, or archive the workspace and start a new one from its branch."
            : "The folders of \(missing.count) workspaces are not on disk any more: "
                + missing.map { "`\($0.name)`" }.joined(separator: ", ")
                + ". Restore them, or archive them and start new ones from their branches."
        return Notice(message: message, tone: .warning, dismissal: .untilDismissed)
    }
}
