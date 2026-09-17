import Foundation

public enum CrashLogName {
    public static func forReport(at instant: Date, existing: Set<String> = []) -> String {
        let stamp = formatter.string(from: instant)
        let first = "crash-\(stamp).log"
        guard existing.contains(first) else { return first }
        var index = 2
        while existing.contains("crash-\(stamp)-\(index).log") { index += 1 }
        return "crash-\(stamp)-\(index).log"
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        return formatter
    }()
}
