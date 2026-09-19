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

    public static func openField(_ renaming: String?, among entries: [PaneContent]) -> String? {
        guard let renaming, entries.contains(where: { $0.id == renaming }) else { return nil }
        return renaming
    }
}
