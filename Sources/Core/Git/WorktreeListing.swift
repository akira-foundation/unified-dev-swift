import Foundation

public struct WorktreeEntry: Sendable, Hashable {
    public var path: String
    public var head: String
    public var branch: String?
    public var isBare: Bool
    public var isDetached: Bool
    public var lockReason: String?
    public var pruneReason: String?

    public var isLocked: Bool { lockReason != nil }
    public var isPrunable: Bool { pruneReason != nil }

    public init(
        path: String,
        head: String = "",
        branch: String? = nil,
        isBare: Bool = false,
        isDetached: Bool = false,
        lockReason: String? = nil,
        pruneReason: String? = nil
    ) {
        self.path = path
        self.head = head
        self.branch = branch
        self.isBare = isBare
        self.isDetached = isDetached
        self.lockReason = lockReason
        self.pruneReason = pruneReason
    }
}

public enum WorktreeListing {
    public static func parse(_ porcelain: Data) -> [WorktreeEntry] {
        parseFields(porcelain.split(separator: 0, omittingEmptySubsequences: false).map {
            String(decoding: $0, as: UTF8.self)
        })
    }

    public static func parse(_ porcelain: String) -> [WorktreeEntry] {
        parseFields(porcelain.components(separatedBy: "\n").map {
            $0.hasSuffix("\r") ? String($0.dropLast()) : $0
        })
    }

    private static func parseFields(_ fields: [String]) -> [WorktreeEntry] {
        var entries: [WorktreeEntry] = []
        var current: WorktreeEntry?

        func flush() {
            if let current { entries.append(current) }
            current = nil
        }

        for line in fields {
            if line.isEmpty {
                flush()
            } else if let path = value(of: "worktree", in: line) {
                flush()
                current = WorktreeEntry(path: path)
            } else if current == nil {
                continue
            } else if let head = value(of: "HEAD", in: line) {
                current?.head = head
            } else if let ref = value(of: "branch", in: line) {
                current?.branch = ref.hasPrefix("refs/heads/")
                    ? String(ref.dropFirst("refs/heads/".count))
                    : ref
            } else if line == "bare" {
                current?.isBare = true
            } else if line == "detached" {
                current?.isDetached = true
            } else if line == "locked" {
                current?.lockReason = ""
            } else if let reason = value(of: "locked", in: line) {
                current?.lockReason = reason
            } else if line == "prunable" {
                current?.pruneReason = ""
            } else if let reason = value(of: "prunable", in: line) {
                current?.pruneReason = reason
            }
        }
        flush()
        return entries
    }

    private static func value(of keyword: String, in line: String) -> String? {
        let prefix = keyword + " "
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count))
    }
}
