import Foundation

enum SettingsTabRequest {
    static let name = Notification.Name("io.akira.unifieddev.settings.tab")

    @MainActor private static var pending: SettingsTab?

    @MainActor
    static func post(_ tab: SettingsTab) {
        pending = tab
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["tab": tab.rawValue])
    }

    @MainActor
    static func takePending() -> SettingsTab? {
        defer { pending = nil }
        return pending
    }

    static func tab(in notification: Notification) -> SettingsTab? {
        (notification.userInfo?["tab"] as? String).flatMap(SettingsTab.init(rawValue:))
    }
}
