import Foundation

public enum WorkspaceDraftRows {
    public static let title = "New workspace"
    public static let accessibilityLabel = "New workspace, draft"

    public enum Slot: Equatable, Sendable {
        case workspaces
        case pending
        case draft
        case emptyNotice
    }

    public enum Departure: Equatable, Sendable {
        case keep
        case discard
    }

    public static func shows(hasContent: Bool, isOpen: Bool, isCreating: Bool) -> Bool {
        hasContent || isOpen || isCreating
    }

    public static func departure(hasContent: Bool, isCreating: Bool) -> Departure {
        hasContent || isCreating ? .keep : .discard
    }

    public static func slots(
        isCollapsed: Bool, workspaceCount: Int, pendingCount: Int, showsDraft: Bool
    ) -> [Slot] {
        guard !isCollapsed else { return showsDraft ? [.draft] : [] }
        guard workspaceCount > 0 || pendingCount > 0 || showsDraft else { return [.emptyNotice] }
        return showsDraft ? [.workspaces, .pending, .draft] : [.workspaces, .pending]
    }

    public static func drawnPending(
        _ pending: [PendingWorkspace], creating: Set<WorkspaceID>
    ) -> [PendingWorkspace] {
        pending.filter { !creating.contains($0.id) }
    }
}
