import Foundation

public struct FileChipTarget: Equatable, Sendable {
    public var path: String
    public var worktree: String
    public var opens: String?

    public static func resolve(_ path: String, in worktree: String) -> FileChipTarget {
        guard let inside = FilePathGuess.relative(path, to: worktree) else {
            return FileChipTarget(path: path, worktree: "", opens: nil)
        }
        return FileChipTarget(path: inside, worktree: worktree, opens: inside)
    }
}
