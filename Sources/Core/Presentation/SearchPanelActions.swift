import Foundation

public enum SearchPanelActions {
    public static let order: [WorkspaceMenuAction] = [
        .openInEditor,
        .revealInFinder,
        .copyName,
        .copyBranchName,
        .pin,
        .unreadMark,
        .rename,
        .restore,
        .archive,
    ]

    public static func rows(for subject: WorkspaceMenuSubject) -> [SearchPanelCommandHit] {
        order
            .filter { subject.allows($0) }
            .map { SearchPanelCommandHit(item: MenuBarCatalogue[menuBarAction(for: $0)]) }
    }

    public static func sections(for subject: WorkspaceMenuSubject) -> [SearchPanelSection] {
        let rows = rows(for: subject)
        guard !rows.isEmpty else { return [] }
        return [SearchPanelSection(id: "actions", title: nil, rows: rows.map { .command($0) })]
    }

    public static func menuBarAction(for action: WorkspaceMenuAction) -> MenuBarAction {
        switch action {
        case .archive: .archive
        case .restore: .restore
        case .openInEditor: .openInEditor
        case .revealInFinder: .revealInFinder
        case .copyBranchName: .copyBranchName
        case .rename: .renameWorkspace
        case .pin: .pin
        case .unreadMark: .unreadMark
        case .colour: .colour
        case .copyName: .copyName
        }
    }

    public static func workspaceAction(for action: MenuBarAction) -> WorkspaceMenuAction? {
        WorkspaceMenuAction.allCases.first { menuBarAction(for: $0) == action }
    }
}
