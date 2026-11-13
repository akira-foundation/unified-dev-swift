import Foundation

public struct BranchPullRequest: Sendable, Equatable {
    public let number: Int
    public let isOpen: Bool
    public let headCommit: String?

    public init(number: Int, isOpen: Bool, headCommit: String? = nil) {
        self.number = number
        self.isOpen = isOpen
        self.headCommit = headCommit
    }
}

public struct BranchInFlight: Sendable, Equatable {
    public let branch: String
    public let openPullRequests: [Int]
    public let unpushedCommits: Int

    public init(branch: String, openPullRequests: [Int], unpushedCommits: Int) {
        self.branch = branch
        self.openPullRequests = openPullRequests
        self.unpushedCommits = unpushedCommits
    }

    public var isInFlight: Bool { !openPullRequests.isEmpty || unpushedCommits > 0 }
}

public enum MergeArchiveInFlight {
    public static func objection(_ branches: [BranchInFlight]) -> String? {
        let open = Array(Set(branches.flatMap(\.openPullRequests))).sorted()
        let unpushed = branches.filter { $0.openPullRequests.isEmpty && $0.unpushedCommits > 0 }
        var sentences: [String] = []
        if !open.isEmpty {
            let numbers = list(open.map { "#\($0)" })
            sentences.append("\(numbers) \(open.count == 1 ? "is" : "are") still open.")
        }
        for branch in unpushed {
            let commits = branch.unpushedCommits == 1 ? "1 commit" : "\(branch.unpushedCommits) commits"
            sentences.append("\(branch.branch) has \(commits) that \(branch.unpushedCommits == 1 ? "is" : "are") not pushed.")
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    public static func checkedOutBranches(reflogSubjects: String) -> [String] {
        let prefix = "checkout: moving from "
        var seen: [String] = []
        for line in reflogSubjects.split(whereSeparator: \.isNewline) where line.hasPrefix(prefix) {
            let parts = line.dropFirst(prefix.count).components(separatedBy: " to ")
            guard parts.count == 2 else { continue }
            for name in [parts[1], parts[0]] where !name.isEmpty && !seen.contains(name) {
                seen.append(name)
            }
        }
        return seen
    }

    public static func candidates(
        checkedOut: [String], current: String?, localBranches: Set<String>, merged: String
    ) -> [String] {
        var ordered: [String] = []
        for name in [current].compactMap(\.self) + checkedOut
        where name != merged && localBranches.contains(name) && !ordered.contains(name) {
            ordered.append(name)
        }
        return ordered
    }

    public static func excludedHeads(_ pullRequests: [BranchPullRequest]) -> [String] {
        pullRequests.compactMap(\.headCommit).filter { !$0.isEmpty }
    }

    public static func standing(
        branch: String, pullRequests: [BranchPullRequest], unpushedCommits: Int
    ) -> BranchInFlight {
        BranchInFlight(
            branch: branch,
            openPullRequests: pullRequests.filter(\.isOpen).map(\.number).sorted(),
            unpushedCommits: unpushedCommits
        )
    }

    private static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + last
    }
}
