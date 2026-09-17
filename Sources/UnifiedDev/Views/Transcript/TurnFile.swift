import Foundation
import Core

struct TurnFile: Identifiable, Hashable, Sendable {
    var path: String
    var additions: Int
    var deletions: Int

    var id: String { path }
    var name: String { ToolPresenter.basename(path) }

    func display(in worktree: String) -> String {
        FilePathGuess.relative(path, to: worktree) ?? path
    }
}
