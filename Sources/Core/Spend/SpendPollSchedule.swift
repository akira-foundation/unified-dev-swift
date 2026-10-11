import Foundation

public enum SpendPollSchedule {
    public static let interval: TimeInterval = 300

    public static let onDemandFloor: TimeInterval = 20

    public static func isDue(lastReadAt: Date?, at now: Date, after gap: TimeInterval) -> Bool {
        guard let lastReadAt else { return true }
        return now.timeIntervalSince(lastReadAt) >= gap
    }
}
