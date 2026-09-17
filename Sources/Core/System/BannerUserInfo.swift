import Foundation

public enum BannerUserInfo {
    private static let workspaceKey = "unifieddevWorkspaceID"

    public static func encode(workspaceID: WorkspaceID) -> [String: String] {
        [workspaceKey: workspaceID.rawValue]
    }

    public static func workspaceID(from userInfo: [AnyHashable: Any]) -> WorkspaceID? {
        guard let raw = userInfo[workspaceKey] as? String, !raw.isEmpty else { return nil }
        return WorkspaceID(raw)
    }
}
