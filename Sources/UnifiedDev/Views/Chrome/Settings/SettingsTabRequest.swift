import Foundation

enum SettingsTabRequest {
    static let name = Notification.Name("io.akira.unifieddev.settings.tab")

    static func post(_ tab: SettingsTab) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["tab": tab.rawValue])
    }

    static func tab(in notification: Notification) -> SettingsTab? {
        (notification.userInfo?["tab"] as? String).flatMap(SettingsTab.init(rawValue:))
    }
}
