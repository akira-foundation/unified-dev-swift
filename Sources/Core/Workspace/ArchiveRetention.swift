import Foundation

public struct ArchiveRetention: Sendable, Hashable {
    public static let daysKey = "archive.retention.days"
    public static let megabytesKey = "archive.retention.megabytes"
    public static let offeredDays = [7, 14, 30, 60, 90, 180, 365]
    public static let offeredMegabytes = [500, 1_000, 2_000, 5_000, 10_000, 50_000]
    public static let sizeLimitGrace: TimeInterval = 86_400
    public static let sweepInterval: TimeInterval = 3_600

    public var days: Int?
    public var megabytes: Int?

    public init(days: Int? = nil, megabytes: Int? = nil) {
        self.days = days
        self.megabytes = megabytes
    }

    public var isEnabled: Bool { Self.limit(days) != nil || Self.limit(megabytes) != nil }

    public func expired(
        in footprints: [ArchivedWorkspaceFootprint],
        now: Date,
        protecting protected: Set<WorkspaceID> = []
    ) -> [ArchivedWorkspaceFootprint] {
        let oldestFirst = footprints.sorted { $0.archivedAt < $1.archivedAt }
        var expired: [ArchivedWorkspaceFootprint] = []
        var kept: [ArchivedWorkspaceFootprint] = []
        for footprint in oldestFirst {
            let isTooOld = maximumAge.map { now.timeIntervalSince(footprint.archivedAt) >= $0 } ?? false
            if isTooOld, !protected.contains(footprint.id) {
                expired.append(footprint)
            } else {
                kept.append(footprint)
            }
        }

        guard let maximumBytes else { return expired }
        var remaining = kept.reduce(0) { $0 + $1.totalBytes }
        for footprint in kept where remaining > maximumBytes {
            guard now.timeIntervalSince(footprint.archivedAt) >= Self.sizeLimitGrace else { break }
            guard !protected.contains(footprint.id) else { continue }
            expired.append(footprint)
            remaining -= footprint.totalBytes
        }
        return expired
    }

    private var maximumAge: TimeInterval? {
        Self.limit(days).map { Double($0) * 86_400 }
    }

    private var maximumBytes: Int? {
        Self.limit(megabytes).map { value in
            let (bytes, overflowed) = value.multipliedReportingOverflow(by: 1_000_000)
            return overflowed ? Int.max : bytes
        }
    }

    private static func limit(_ value: Int?) -> Int? {
        value.flatMap { $0 > 0 ? $0 : nil }
    }

    public static func load(from store: Store) async -> ArchiveRetention {
        ArchiveRetention(
            days: parse(try? await store.setting(daysKey)),
            megabytes: parse(try? await store.setting(megabytesKey))
        )
    }

    public func save(to store: Store) async throws {
        try await store.setSetting(Self.daysKey, Self.limit(days).map(String.init))
        try await store.setSetting(Self.megabytesKey, Self.limit(megabytes).map(String.init))
    }

    private static func parse(_ stored: String?) -> Int? {
        limit(stored.flatMap { Int($0) })
    }

    public static func daysLabel(_ days: Int) -> String {
        Counted.of(days, "day")
    }

    public static func sizeLabel(_ megabytes: Int) -> String {
        ArchiveDeletion.bytes(megabytes * 1_000_000)
    }

    public static func footer(wouldDelete expired: [ArchivedWorkspaceFootprint]?) -> String {
        let rule = """
        Permanently deletes the transcripts, notes and review comments of archived workspaces, oldest \
        first, when Unified Dev opens and every hour. The size counts what they hold in the database, \
        and anything archived in the last day is kept whatever its size.
        """
        guard let expired, !expired.isEmpty else { return rule }
        let bytes = expired.reduce(0) { $0 + $1.totalBytes }
        return rule + " "
            + "At the next check this deletes \(Counted.of(expired.count, "archived workspace")), "
            + "\(ArchiveDeletion.bytes(bytes))."
    }

    public static func notice(deleted count: Int, bytes: Int) -> Notice {
        Notice(
            message: "Deleted \(Counted.of(count, "archived workspace")), \(ArchiveDeletion.bytes(bytes)). "
                + "They passed the limits in Workspaces settings."
        )
    }
}
