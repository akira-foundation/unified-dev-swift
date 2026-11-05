import Foundation
import Core

enum RepoSettingsPaneRequest {
    static let name = Notification.Name("io.akira.unifieddev.repo-settings.pane")

    @MainActor private static var pending: [RepoID: RepoSettingsPane] = [:]

    @MainActor
    static func post(_ pane: RepoSettingsPane, for repoID: RepoID) {
        pending[repoID] = pane
        NotificationCenter.default.post(
            name: name, object: nil, userInfo: ["pane": pane.rawValue, "repo": repoID.rawValue]
        )
    }

    @MainActor
    static func takePending(for repoID: RepoID) -> RepoSettingsPane? {
        pending.removeValue(forKey: repoID)
    }

    static func pane(in notification: Notification, for repoID: RepoID) -> RepoSettingsPane? {
        guard notification.userInfo?["repo"] as? String == repoID.rawValue else { return nil }
        return (notification.userInfo?["pane"] as? String).flatMap(RepoSettingsPane.init(rawValue:))
    }
}
