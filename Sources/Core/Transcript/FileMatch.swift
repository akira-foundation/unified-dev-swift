import Foundation

public struct FileMatch: Identifiable, Hashable, Sendable {
    public var path: String
    public var score: Int

    public var id: String { path }

    public var fileName: String {
        (path as NSString).lastPathComponent
    }

    public var directory: String {
        (path as NSString).deletingLastPathComponent
    }

    public nonisolated static func search(_ paths: [String], query: String, limit: Int) -> [FileMatch] {
        guard !query.isEmpty else {
            return paths.prefix(limit).map { FileMatch(path: $0, score: 0) }
        }

        var found: [FileMatch] = []
        found.reserveCapacity(min(paths.count, limit * 4))

        for path in paths {
            guard let score = FuzzyMatch.score(path, query: query) else { continue }
            let nameBonus = FuzzyMatch.score((path as NSString).lastPathComponent, query: query) ?? 0
            found.append(FileMatch(path: path, score: score + nameBonus))
        }

        found.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.path.count != rhs.path.count { return lhs.path.count < rhs.path.count }
            return lhs.path < rhs.path
        }
        return Array(found.prefix(limit))
    }
}
