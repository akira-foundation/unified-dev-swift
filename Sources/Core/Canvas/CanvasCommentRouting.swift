import Foundation

public enum CanvasCommentRouting {
    public static func target(
        besideChat: SessionID?, shownBy: SessionID?, active: SessionID?, accepting accepts: (SessionID) -> Bool = { _ in true }
    ) -> SessionID? {
        [besideChat, shownBy, active].compactMap(\.self).first(where: accepts)
    }
}
