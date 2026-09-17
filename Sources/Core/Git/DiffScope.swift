import Foundation

public struct BranchCommit: Sendable, Hashable, Identifiable {
    public let sha: String
    public let subject: String
    public let author: String
    public let date: Date

    public var id: String { sha }

    public var abbreviated: String { String(sha.prefix(7)) }

    public init(sha: String, subject: String, author: String, date: Date) {
        self.sha = sha
        self.subject = subject
        self.author = author
        self.date = date
    }
}

public enum DiffScope: Sendable, Hashable {
    case all
    case uncommitted
    case since(BranchCommit)

    public var isNarrowed: Bool { self != .all }

    public func revision(baseline: String) -> String {
        switch self {
        case .all: baseline
        case .uncommitted: "HEAD"
        case .since(let commit): commit.sha
        }
    }

    public var title: String {
        switch self {
        case .all: "All changes"
        case .uncommitted: "Uncommitted changes"
        case .since(let commit): "Since \(commit.subject)"
        }
    }

    public var badge: String {
        switch self {
        case .all: "All changes"
        case .uncommitted: "Uncommitted"
        case .since(let commit): "Since \(commit.abbreviated)"
        }
    }

    public func emptyMessage(base: String) -> String {
        switch self {
        case .all: "Nothing in this worktree differs from \(base)."
        case .uncommitted: "Everything in this worktree is committed."
        case .since(let commit): "Nothing has changed since \(commit.abbreviated)."
        }
    }
}

public struct BranchCommitList: Sendable, Hashable {
    public var commits: [BranchCommit]
    public var isTruncated: Bool

    public init(commits: [BranchCommit] = [], isTruncated: Bool = false) {
        self.commits = commits
        self.isTruncated = isTruncated
    }

    public static let limit = 50

    public var truncationNote: String? {
        isTruncated ? "Only the newest \(Self.limit) commits are listed." : nil
    }

    public func canOffer(_ scope: DiffScope) -> Bool {
        guard case .since(let commit) = scope else { return true }
        return commits.contains { $0.sha == commit.sha }
    }

    public func resolve(_ scope: DiffScope) -> DiffScope {
        canOffer(scope) ? scope : .all
    }
}

public extension DiffScope {
    func strandedComments(
        _ comments: [ReviewComment], among files: [ChangedFile]
    ) -> [ReviewComment] {
        guard isNarrowed else { return [] }
        let shown = Set(files.map(\.path))
        return comments.filter { !shown.contains($0.filePath) }
    }

    func strandedNote(_ comments: [ReviewComment], among files: [ChangedFile]) -> String? {
        let stranded = strandedComments(comments, among: files)
        guard !stranded.isEmpty else { return nil }
        let count = stranded.count
        return "\(count) review comment\(count == 1 ? " is" : "s are") on files this scope leaves"
            + " out. \(count == 1 ? "It is" : "They are") kept, and still sent with your next"
            + " message."
    }
}
