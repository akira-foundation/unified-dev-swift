import Foundation

public struct ReviewedFile: Sendable, Hashable, Codable {
    public var workspaceID: WorkspaceID
    public var path: String
    public var fingerprint: String
    public var viewedAt: Date

    public init(
        workspaceID: WorkspaceID,
        path: String,
        fingerprint: String,
        viewedAt: Date = Date()
    ) {
        self.workspaceID = workspaceID
        self.path = path
        self.fingerprint = fingerprint
        self.viewedAt = viewedAt
    }
}

public enum ReviewedFileFingerprint {
    public static func of(_ file: ChangedFile, revision: String = "") -> String {
        let counts = "\(file.change.rawValue):\(file.additions):\(file.deletions):\(file.isBinary ? 1 : 0)"
        return revision.isEmpty ? counts : counts + ":" + revision
    }

    public static func revisions(for files: [ChangedFile], worktree: String, base: String, scope: DiffScope) -> [String: String] {
        let comparison = scope.revision(baseline: base)
        return Dictionary(uniqueKeysWithValues: files.map { file in
            let path = (worktree as NSString).appendingPathComponent(file.path)
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate
            let size = (attributes?[.size] as? NSNumber)?.uint64Value
            let inode = (attributes?[.systemFileNumber] as? NSNumber)?.uint64Value
            let stamp = "\(comparison):\(modified.map { String($0) } ?? "missing"):\(size.map { String($0) } ?? "missing"):\(inode.map { String($0) } ?? "missing")"
            return (file.path, stamp)
        })
    }
}

public enum ReviewedFiles {
    public static func isViewed(_ file: ChangedFile, marks: [String: String], revisions: [String: String] = [:]) -> Bool {
        marks[file.path] == ReviewedFileFingerprint.of(file, revision: revisions[file.path] ?? "")
    }

    public static func viewedCount(among files: [ChangedFile], marks: [String: String], revisions: [String: String] = [:]) -> Int {
        files.count(where: { isViewed($0, marks: marks, revisions: revisions) })
    }

    public static func summary(among files: [ChangedFile], marks: [String: String], revisions: [String: String] = [:]) -> String? {
        let total = files.count
        guard total > 0 else { return nil }
        let viewed = viewedCount(among: files, marks: marks, revisions: revisions)
        guard viewed > 0 else { return nil }
        if viewed >= total {
            return "All \(Counted.of(total, "file")) viewed"
        }
        return "\(viewed) of \(total) files viewed"
    }

    public static func unviewed(
        among files: [ChangedFile],
        marks: [String: String],
        revisions: [String: String] = [:]
    ) -> [ChangedFile] {
        files.filter { !isViewed($0, marks: marks, revisions: revisions) }
    }
}

public enum ReviewedMarkAction: String, Sendable, Hashable, CaseIterable {
    case markViewed
    case markNotViewed

    public init(isViewed: Bool) {
        self = isViewed ? .markNotViewed : .markViewed
    }

    public var title: String {
        switch self {
        case .markViewed: "Mark as Viewed"
        case .markNotViewed: "Mark as Not Viewed"
        }
    }

    public var isViewed: Bool { self == .markViewed }

    public func help(for filename: String) -> String {
        switch self {
        case .markViewed: "Mark \(filename) as viewed (Option+V)"
        case .markNotViewed: "Mark \(filename) as not yet viewed (Option+V)"
        }
    }
}
