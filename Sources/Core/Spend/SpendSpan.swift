import Foundation

public enum SpendSpan: String, Sendable, Hashable, CaseIterable, Identifiable {
    case today
    case week
    case month

    public var id: String { rawValue }

    public var days: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }

    public var label: String {
        switch self {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        }
    }

    public func start(from now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
    }

    public func dayStarts(from now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<days)
            .compactMap { calendar.date(byAdding: .day, value: -($0), to: today) }
            .reversed()
    }
}
