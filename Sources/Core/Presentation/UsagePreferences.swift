import Foundation

public enum UsagePreferenceKey {
    public static let layout = "menuBar.usage.layout"
    public static let meterStyle = "menuBar.usage.meterStyle"
    public static let iconStyle = "menuBar.usage.iconStyle"
    public static let showsUsage = "menuBar.usage.showsFigures"
    public static let showsCup = "menuBar.usage.showsCup"
    public static let showsWaitingCount = "menuBar.showsWaitingCount"
    public static let showsUnreadCount = "menuBar.showsUnreadCount"
}

public enum UsageMeterStyle: String, CaseIterable, Sendable {
    case left
    case used

    public var title: String {
        switch self {
        case .left: "Left"
        case .used: "Used"
        }
    }

    public var toggled: UsageMeterStyle { self == .left ? .used : .left }
}

public enum UsageResetDisplay: String, CaseIterable, Sendable {
    case countdown
    case exactTime

    public var title: String {
        switch self {
        case .countdown: "Countdown"
        case .exactTime: "Exact Time"
        }
    }

    public var toggled: UsageResetDisplay { self == .countdown ? .exactTime : .countdown }
}

public enum UsageTimeFormat: String, CaseIterable, Sendable {
    case automatic = "auto"
    case twelveHour = "12h"
    case twentyFourHour = "24h"

    public var title: String {
        switch self {
        case .automatic: "Auto"
        case .twelveHour: "12-hour"
        case .twentyFourHour: "24-hour"
        }
    }
}

public enum MenuBarIconStyle: String, CaseIterable, Sendable {
    case text
    case bars

    public var title: String {
        switch self {
        case .text: "Text"
        case .bars: "Bars"
        }
    }
}

public enum UsageDensity: String, CaseIterable, Sendable {
    case regular
    case compact

    public var title: String {
        switch self {
        case .regular: "Default"
        case .compact: "Compact"
        }
    }
}

public struct UsageDisplayOptions: Sendable, Hashable {
    public var meterStyle: UsageMeterStyle
    public var resetDisplay: UsageResetDisplay
    public var alwaysShowsPacing: Bool
    public var timeFormat: UsageTimeFormat
    public var calendar: Calendar
    public var locale: Locale

    public init(
        meterStyle: UsageMeterStyle = .left,
        resetDisplay: UsageResetDisplay = .countdown,
        alwaysShowsPacing: Bool = false,
        timeFormat: UsageTimeFormat = .automatic,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) {
        self.meterStyle = meterStyle
        self.resetDisplay = resetDisplay
        self.alwaysShowsPacing = alwaysShowsPacing
        self.timeFormat = timeFormat
        self.calendar = calendar
        self.locale = locale
    }
}
