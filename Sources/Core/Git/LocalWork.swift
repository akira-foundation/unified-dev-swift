import Foundation

public struct LocalWork: Sendable, Hashable {
    public var modifiedFiles: Int
    public var untrackedFiles: Int
    public var unpushedCommits: Int
    public var hasUpstream: Bool

    public init(
        modifiedFiles: Int = 0,
        untrackedFiles: Int = 0,
        unpushedCommits: Int = 0,
        hasUpstream: Bool = true
    ) {
        self.modifiedFiles = modifiedFiles
        self.untrackedFiles = untrackedFiles
        self.unpushedCommits = unpushedCommits
        self.hasUpstream = hasUpstream
    }

    public var hasUncommitted: Bool { modifiedFiles > 0 || untrackedFiles > 0 }

    public var hasUnpushed: Bool { hasUpstream && unpushedCommits > 0 }

    public var isAhead: Bool { hasUncommitted || hasUnpushed }
}
