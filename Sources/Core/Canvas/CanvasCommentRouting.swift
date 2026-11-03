import Foundation

public enum CanvasCommentRouting {
    public static func target(besideChat: SessionID?, shownBy: SessionID?, active: SessionID?) -> SessionID? {
        besideChat ?? shownBy ?? active
    }
}
