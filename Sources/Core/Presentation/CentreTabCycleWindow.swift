import Foundation

public enum CentreTabCycleWindow {
    public static func cycles(
        role: WindowDismissal.Role, identifier: String?, mainSceneID: String
    ) -> Bool {
        guard role == .workspace, !mainSceneID.isEmpty, let identifier else { return false }
        return identifier.contains(mainSceneID)
    }
}
