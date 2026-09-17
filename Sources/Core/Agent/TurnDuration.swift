import Foundation

public enum TurnDuration {
    private static func tenths(_ locale: Locale) -> FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(1)).locale(locale)
    }

    private static func whole(_ locale: Locale) -> FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(0)).locale(locale)
    }

    public static func format(_ milliseconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let seconds = max(0, Double(milliseconds)) / 1000

        if (seconds * 10).rounded() < 600 { return "\(seconds.formatted(tenths(locale)))s" }

        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)

        if minutes < 10 {
            return (remainder * 10).rounded() < 600
                ? "\(minutes)m \(remainder.formatted(tenths(locale)))s"
                : "\(minutes + 1)m \(Double.zero.formatted(tenths(locale)))s"
        }
        return remainder.rounded() < 60
            ? "\(minutes)m \(remainder.formatted(whole(locale)))s"
            : "\(minutes + 1)m 0s"
    }

    public static func wholeSeconds(_ milliseconds: Int) -> String {
        let seconds = Int((Double(max(0, milliseconds)) / 1000).rounded())
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes == 0 ? "\(seconds)s" : "\(minutes)m \(remainder)s"
    }

    public static func short(_ milliseconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let clamped = max(0, milliseconds)
        if clamped < 1000 { return "\(clamped)ms" }

        let seconds = Double(clamped) / 1000
        if (seconds * 10).rounded() < 600 { return "\(seconds.formatted(tenths(locale)))s" }

        return "\(max(1, clamped / 60_000))m"
    }
}
