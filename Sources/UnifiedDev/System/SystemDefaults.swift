import Foundation
import Core

@MainActor
enum SystemDefaults {
    private static var isRegistered = false

    static func registerOnce() {
        guard !isRegistered else { return }
        isRegistered = true

        UserDefaults.standard.register(defaults: [
            SleepPrevention.settingKey: SleepPrevention.isOnByDefault,
            MenuBarStatusItem.settingKey: MenuBarStatusItem.isOnByDefault,
            InstallPing.settingKey: InstallPing.isOnByDefault,
            CrashReporting.settingKey: CrashReporting.isOnByDefault,
        ])
    }
}
