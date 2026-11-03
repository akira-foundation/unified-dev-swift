import Foundation

public enum SelectionActions {
    public static func accepts(_ kind: MessageKind) -> Bool {
        kind == .user || kind == .assistantText
    }

    public static func canBranch(isAsk: Bool, isSideConversation: Bool, workspaceIsActive: Bool) -> Bool {
        !isAsk && !isSideConversation && workspaceIsActive
    }
}
