import Foundation

public enum SleepPrevention {
    public static let settingKey = "system.preventsSleepWhileRunning"

    public static let isOnByDefault = true

    public static let settingTitle = "Keep the Mac awake while agents are running"

    public static let settingDetail =
        "Prevents idle sleep until all agents finish. The display can still sleep."

    public static let menuItemTitle = "Prevent Sleep While Agents Run"

    public static let caveat =
        "Closing the lid can still put the Mac to sleep and pause agents. Keeping it awake uses more battery."

    public static func preventsSleep(isEnabled: Bool, runningCount: Int) -> Bool {
        isEnabled && runningCount > 0
    }
}
