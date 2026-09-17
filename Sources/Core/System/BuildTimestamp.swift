import Foundation

public enum BuildTimestamp {
    public static let infoKey = "BuildDate"

    public static func read(from bundle: Bundle) -> Date? {
        read(
            stamp: bundle.object(forInfoDictionaryKey: infoKey) as? String,
            executableModified: executableModified(of: bundle)
        )
    }

    public static func read(stamp: String?, executableModified: Date?) -> Date? {
        parse(stamp) ?? executableModified
    }

    public static func parse(_ stamp: String?) -> Date? {
        guard let stamp else { return nil }
        let trimmed = stamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: trimmed)
    }

    public static func line(
        _ date: Date,
        now: Date = Date(),
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)

        let day = formatter(template: sameYear ? "MMMd" : "yMMMd", locale, timeZone)
        let time = formatter(template: "jmm", locale, timeZone)
        return "\(day.string(from: date)) \(time.string(from: date))"
    }

    private static func formatter(
        template: String, _ locale: Locale, _ timeZone: TimeZone
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static func executableModified(of bundle: Bundle) -> Date? {
        guard let url = bundle.executableURL else { return nil }
        return try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
    }
}
