import Foundation

public enum NotificationBellReading {
    public static let maximumShown = 99

    public static func badge(unseen: Int) -> String? {
        guard unseen > 0 else { return nil }
        return unseen > maximumShown ? "\(maximumShown)+" : "\(unseen)"
    }

    public static func accessibilityLabel(unseen: Int) -> String {
        switch unseen {
        case 0: "Notifications, none unseen"
        case 1: "Notifications, 1 unseen"
        default: "Notifications, \(unseen) unseen"
        }
    }
}
