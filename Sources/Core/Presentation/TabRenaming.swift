import Foundation

public enum TabRenaming {
    public static func canRename(_ content: PaneContent, tabKind: CenterTabKind?) -> Bool {
        switch content {
        case .chat:
            return true
        case .tool:
            switch tabKind {
            case .terminal, .browser: return true
            case .review, .notes, nil: return false
            }
        }
    }
}
