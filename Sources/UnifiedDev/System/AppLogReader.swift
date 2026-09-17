import Foundation
import OSLog
import Core

enum AppLogReader {
    static let subsystem = Bundle.main.bundleIdentifier ?? "io.akira.unifieddev"

    nonisolated static func recent(
        window: TimeInterval = AppLogExcerpt.window,
        limit: Int = AppLogExcerpt.maxEntries,
        now: Date = Date()
    ) -> [AppLogExcerpt.Entry] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return [] }

        let since = now.addingTimeInterval(-window)
        let predicate = NSPredicate(format: "subsystem == %@", subsystem)
        guard let entries = try? store.getEntries(at: store.position(date: since), matching: predicate) else {
            return []
        }

        var found: [AppLogExcerpt.Entry] = []
        for case let entry as OSLogEntryLog in entries {
            guard entry.date >= since else { continue }

            found.append(
                AppLogExcerpt.Entry(
                    date: entry.date,
                    category: entry.category,
                    message: entry.composedMessage
                )
            )
            if found.count > limit { found.removeFirst() }
        }
        return found
    }
}
