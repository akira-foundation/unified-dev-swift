import Foundation

public enum SpendFormat {
    public static let currency = "USD"

    public static func money(_ amount: Double) -> String {
        if amount > 0, amount < 0.01 { return "<$0.01" }
        return amount.formatted(.currency(code: currency).precision(.fractionLength(2)))
    }

    public static func tokens(_ count: Int) -> String {
        let value = Double(count)
        switch count {
        case 1_000_000_000...: return string(value / 1_000_000_000, "B")
        case 1_000_000...: return string(value / 1_000_000, "M")
        case 1_000...: return string(value / 1_000, "K")
        default: return "\(count)"
        }
    }

    public static func share(_ fraction: Double) -> String {
        let percent = fraction * 100
        if percent > 0, percent < 0.1 { return "<" + 0.1.formatted(.number.precision(.fractionLength(1))) + "%" }
        return percent.formatted(.number.precision(.fractionLength(percent < 10 ? 1 : 0))) + "%"
    }

    public static func measuredOn(_ date: Date) -> String {
        "At API rates, priced " + date.formatted(
            Date.FormatStyle(date: .long, timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt)
        )
    }

    public static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private static func string(_ value: Double, _ suffix: String) -> String {
        value.formatted(.number.precision(.fractionLength(value < 10 ? 2 : 1))) + " " + suffix
    }
}
