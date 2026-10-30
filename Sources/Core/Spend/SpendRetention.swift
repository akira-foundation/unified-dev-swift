import Foundation

public enum SpendRetention {
    public static let days = 400

    public static let pricedOnKey = "spend.pricedOn"

    public static func oldestKept(from now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }

    public static func mustRebuild(storedPricedOn: String?, table: Date) -> Bool {
        storedPricedOn != stamp(of: table)
    }

    public static func stamp(of date: Date) -> String {
        String(Int(date.timeIntervalSince1970.rounded()))
    }
}
