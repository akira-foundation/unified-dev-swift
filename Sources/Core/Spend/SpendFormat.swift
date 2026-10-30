import Foundation

public enum SpendFormat {
    public static let currency = "USD"

    public static func money(_ amount: Double) -> String {
        if amount > 0, amount < 0.01 { return "<$0.01" }
        return amount.formatted(.currency(code: currency).precision(.fractionLength(2)))
    }

    public static let units: [(scale: Double, suffix: String)] = [
        (1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K"),
    ]

    public static func tokens(_ count: Int) -> String {
        for unit in units where Double(count) / unit.scale >= 0.9995 {
            return string(Double(count) / unit.scale, unit.suffix)
        }
        return "\(count)"
    }

    public static func share(_ fraction: Double) -> String {
        let percent = fraction * 100
        if percent > 0, percent < 0.1 { return "<" + 0.1.formatted(.number.precision(.fractionLength(1))) + "%" }
        return percent.formatted(.number.precision(.fractionLength(percent < 10 ? 1 : 0))) + "%"
    }

    public static func pricedOn(_ date: Date) -> String {
        "Priced " + date.formatted(
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
