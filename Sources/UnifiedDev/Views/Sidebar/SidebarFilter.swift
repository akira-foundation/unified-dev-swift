import Core

enum SidebarFilter: String, CaseIterable, Hashable {
    case all = "All workspaces"
    case unread = "Unread"
    case changed = "With changes"

    func accepts(_ workspace: Workspace) -> Bool {
        switch self {
        case .all: true
        case .unread: workspace.unread
        case .changed: workspace.hasDiff
        }
    }

    var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease"
        case .unread: "circle.fill"
        case .changed: "plusminus"
        }
    }
}
