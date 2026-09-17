import Foundation

public enum WorkspaceMenuSubject: Hashable, Sendable {
    case live(WorkspaceID)
    case archived(WorkspaceID)

    public struct FocusedRow: Hashable, Sendable {
        public var id: WorkspaceID
        public var isArchived: Bool

        public init(id: WorkspaceID, isArchived: Bool) {
            self.id = id
            self.isArchived = isArchived
        }
    }

    public static func resolve(
        selection: SidebarSelection, focusedRow: FocusedRow?
    ) -> WorkspaceMenuSubject? {
        if let id = selection.workspaceID { return .live(id) }
        if let id = selection.archivedWorkspaceID { return .archived(id) }
        guard let focusedRow else { return nil }
        return focusedRow.isArchived ? .archived(focusedRow.id) : .live(focusedRow.id)
    }

    public var id: WorkspaceID {
        switch self {
        case .live(let id), .archived(let id): id
        }
    }

    public var liveID: WorkspaceID? {
        if case .live(let id) = self { return id }
        return nil
    }

    public var archivedID: WorkspaceID? {
        if case .archived(let id) = self { return id }
        return nil
    }

    public func allows(_ action: WorkspaceMenuAction) -> Bool {
        switch action {
        case .copyBranchName, .copyName:
            true

        case .restore:
            archivedID != nil

        case .archive, .openInEditor, .revealInFinder, .rename, .pin, .unreadMark, .colour:
            liveID != nil
        }
    }
}

public enum WorkspaceMenuAction: String, Hashable, Sendable, CaseIterable {
    case archive
    case restore
    case openInEditor
    case revealInFinder
    case copyBranchName
    case rename
    case pin
    case unreadMark
    case colour
    case copyName
}
