import Foundation

public enum RecentFolders {
    public static let kept = 10

    public static func adding(
        _ path: String,
        to recent: [String],
        limit: Int = kept
    ) -> [String] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recent }
        let normalized = FolderPath.normalize(trimmed)
        let rest = recent.filter { !FolderPath.sameFolder($0, normalized) }
        return Array(([normalized] + rest).prefix(max(limit, 1)))
    }

    public static func removing(_ path: String, from recent: [String]) -> [String] {
        recent.filter { !FolderPath.sameFolder($0, path) }
    }

    public static func onDisk(
        _ recent: [String],
        exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> [String] {
        var seen: Set<String> = []
        return recent.filter { path in
            guard exists(path), seen.insert(FolderPath.resolved(path)).inserted else { return false }
            return true
        }
    }
}
