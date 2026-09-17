import Foundation

public struct ArchivedWorkspaceFootprint: Sendable, Identifiable, Hashable {
    public let workspace: Workspace
    public let repoName: String
    public let sessionCount: Int
    public let messageCount: Int
    public let transcriptBytes: Int
    public let otherBytes: Int
    public let reviewCommentCount: Int
    public let hasNote: Bool
    public var branchIsLocal: Bool?

    public var id: WorkspaceID { workspace.id }

    public var totalBytes: Int { transcriptBytes + otherBytes }

    public var archivedAt: Date {
        workspace.archivedAt ?? workspace.lastActivityAt
    }

    public var contents: String {
        var parts = [ArchiveDeletion.bytes(totalBytes)]
        if messageCount > 0 {
            parts.append(
                "\(ArchiveDeletion.count(messageCount, "transcript message")) in "
                + "\(ArchiveDeletion.count(sessionCount, "chat"))"
            )
        }
        if branchIsLocal == false { parts.append("branch not on this Mac") }
        return parts.joined(separator: " \u{00B7} ")
    }

    public init(
        workspace: Workspace,
        repoName: String,
        sessionCount: Int,
        messageCount: Int,
        transcriptBytes: Int,
        otherBytes: Int,
        reviewCommentCount: Int,
        hasNote: Bool,
        branchIsLocal: Bool? = nil
    ) {
        self.workspace = workspace
        self.repoName = repoName
        self.sessionCount = sessionCount
        self.messageCount = messageCount
        self.transcriptBytes = transcriptBytes
        self.otherBytes = otherBytes
        self.reviewCommentCount = reviewCommentCount
        self.hasNote = hasNote
        self.branchIsLocal = branchIsLocal
    }
}

public struct ArchiveCleanup: Sendable, Hashable {
    public let footprints: [ArchivedWorkspaceFootprint]

    public init(footprints: [ArchivedWorkspaceFootprint]) {
        self.footprints = footprints
    }

    public var totalBytes: Int {
        footprints.reduce(0) { $0 + $1.totalBytes }
    }

    public var isEmpty: Bool { footprints.isEmpty }
}

public struct DatabaseSize: Sendable, Hashable {
    public let pageSize: Int
    public let pageCount: Int
    public let freePageCount: Int

    public init(pageSize: Int, pageCount: Int, freePageCount: Int) {
        self.pageSize = pageSize
        self.pageCount = pageCount
        self.freePageCount = freePageCount
    }

    public var totalBytes: Int { pageSize * pageCount }
    public var freeBytes: Int { pageSize * freePageCount }
    public var usedBytes: Int { totalBytes - freeBytes }

    public var isWorthCompacting: Bool { freeBytes >= 8 * 1_000_000 }

    public var compactionHelp: String {
        """
        \(ArchiveDeletion.bytes(freeBytes)) inside the database is space nothing is using. \
        Deleting frees pages inside the file; compacting rewrites the file and hands them back to \
        the disk, which takes a while and stops everything else while it runs.
        """
    }
}

public enum ArchiveDeletionOutcome: Sendable, Hashable {
    case deleted(Int)
    case refused(complaint: String)

    public var sentence: String? {
        switch self {
        case .deleted: return nil
        case let .refused(complaint):
            return """
                Unified Dev could not delete those archived workspaces, so they are all still here \
                and nothing has been freed.

                No worktree and no branch was involved: this is the database refusing to write, \
                and it will refuse the next attempt the same way.

                Quit Unified Dev and open it again, and if it happens a second time the database itself \
                needs looking at.

                The database said: \(complaint)
                """
        }
    }

    public var didDelete: Bool {
        if case let .deleted(count) = self { return count > 0 }
        return false
    }
}

public struct ArchiveDeletion: Sendable, Hashable {
    public let footprints: [ArchivedWorkspaceFootprint]

    public init(_ footprints: [ArchivedWorkspaceFootprint]) {
        self.footprints = footprints
    }

    public var isEmpty: Bool { footprints.isEmpty }

    public var totalBytes: Int { footprints.reduce(0) { $0 + $1.totalBytes } }

    public var title: String {
        if let only = footprints.first, footprints.count == 1 {
            return "Delete everything Unified Dev kept about \u{201C}\(only.workspace.name)\u{201D}?"
        }
        return "Delete everything Unified Dev kept about \(Self.count(footprints.count, "archived workspace"))?"
    }

    public var summary: String {
        let subject = footprints.count == 1 ? "This workspace" : "These workspaces"
        let pronoun = footprints.count == 1 ? "its" : "their"
        return """
        \(subject) already lost \(pronoun) worktree when \(footprints.count == 1 ? "it was" : "they were") \
        archived, and that could be undone as long as the branch survived. This cannot. It removes \
        the record from Unified Dev\u{2019}s database, and there is nothing anywhere else that holds a copy.
        """
    }

    public var losses: [String] {
        var losses: [String] = []

        let messages = footprints.reduce(0) { $0 + $1.messageCount }
        let sessions = footprints.reduce(0) { $0 + $1.sessionCount }
        if messages > 0 {
            losses.append(
                "\(Self.count(messages, "transcript message")) across "
                + "\(Self.count(sessions, "chat")), holding \(Self.bytes(totalBytes))"
            )
        } else if totalBytes > 0 {
            losses.append("\(Self.bytes(totalBytes)) of recorded work")
        }

        let comments = footprints.reduce(0) { $0 + $1.reviewCommentCount }
        if comments > 0 {
            losses.append("\(Self.count(comments, "review comment")) written by hand")
        }

        let notes = footprints.filter(\.hasNote).count
        if notes > 0 {
            losses.append(notes == 1 ? "a workspace note" : "\(notes) workspace notes")
        }

        return losses
    }

    public var branchStanding: String? {
        let known = footprints.compactMap(\.branchIsLocal)
        guard known.count == footprints.count, !footprints.isEmpty else { return nil }

        if known.allSatisfy({ $0 }) {
            let branches = footprints.count == 1
                ? "The branch \(footprints[0].workspace.branch) is"
                : "All \(footprints.count) branches are"
            return "\(branches) still on this Mac, so no commit is affected. What goes is the record of the work, not the work."
        }
        if known.allSatisfy({ !$0 }) {
            let subject = footprints.count == 1
                ? "The branch \(footprints[0].workspace.branch) is"
                : "None of these branches are"
            return "\(subject) not on this Mac. If no remote still carries \(footprints.count == 1 ? "it" : "them"), this record is the last thing left of the work."
        }
        let gone = known.filter { !$0 }.count
        return """
        \(gone) of these \(footprints.count) branches \(gone == 1 ? "is" : "are") no longer on this Mac. \
        If no remote still carries \(gone == 1 ? "it" : "them"), \(gone == 1 ? "that record is" : "those records are") \
        the last thing left of that work.
        """
    }

    public var confirmLabel: String { "Delete permanently" }

    public var cancelLabel: String {
        footprints.count == 1 ? "Keep the record" : "Keep the records"
    }

    public var message: String {
        var body = summary
        if !losses.isEmpty {
            body += "\n\nThis deletes:\n" + losses.map { "\u{2022} \($0)" }.joined(separator: "\n")
        }
        if let branchStanding {
            body += "\n\n" + branchStanding
        }
        return body
    }

    public static func count(_ value: Int, _ noun: String, plural: String? = nil) -> String {
        Counted.of(value, noun, plural: plural)
    }

    public static func bytes(_ value: Int) -> String {
        value.formatted(.byteCount(style: .file))
    }
}
