import Foundation

enum WorkspaceDiffBudget: Equatable {
    case tooManyLines(Int)
    case tooManyUntracked(Int)

    static let lineLimit = 20_000
    static let untrackedLimit = 200

    static func exceeded(by files: [ChangedFile]) -> WorkspaceDiffBudget? {
        let lines = lines(in: files)
        guard lines <= lineLimit else { return .tooManyLines(lines) }
        let untracked = files.filter { $0.change == .untracked }.count
        guard untracked <= untrackedLimit else { return .tooManyUntracked(untracked) }
        return nil
    }

    static func lines(in files: [ChangedFile]) -> Int {
        files.reduce(0) { $0 + $1.additions + $1.deletions }
    }

    var sentence: String {
        switch self {
        case .tooManyLines(let lines):
            return """
                The changes come to \(lines) lines added and removed, more than the \
                \(Self.lineLimit) one workspace_diff reads, so the diff is left out and only the \
                file list is here. Pass 'path' with a file from the list to read that file's diff.
                """

        case .tooManyUntracked(let count):
            return """
                The workspace holds \(count) untracked files, more than the \(Self.untrackedLimit) \
                one workspace_diff reads, so the diff is left out and only the file list is here. \
                Pass 'path' with a file from the list to read that file's diff.
                """
        }
    }
}
