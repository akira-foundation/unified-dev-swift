import Foundation

public enum SearchPanelMode: Equatable, Sendable {
    case things
    case commands
    case actions(WorkspaceID)

    public var pill: String? {
        switch self {
        case .things: nil
        case .commands: "Commands"
        case .actions: "Action"
        }
    }

    public var showsScopes: Bool { self == .things }

    public var workspaceID: WorkspaceID? {
        if case .actions(let id) = self { return id }
        return nil
    }
}
