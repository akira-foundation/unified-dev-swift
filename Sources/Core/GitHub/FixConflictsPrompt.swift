import Foundation

public struct FixConflictsPromptContext: Sendable, Hashable {
    public static let noBranch = "(the branch name is not recorded: it is whichever branch this "
        + "worktree is already on, and do not switch away from it)"

    public var workspaceName: String
    public var number: Int
    public var branch: String
    public var baseBranch: String

    public init(workspaceName: String, number: Int, branch: String, baseBranch: String) {
        self.workspaceName = workspaceName
        self.number = number
        self.branch = branch
        self.baseBranch = baseBranch
    }

    public var values: [String: String] {
        [
            PromptRegistry.FixConflicts.workspace: workspaceName,
            PromptRegistry.FixConflicts.number: String(number),
            PromptRegistry.FixConflicts.branch: branch.isEmpty ? Self.noBranch : branch,
            PromptRegistry.FixConflicts.baseBranch: baseBranch,
        ]
    }

    public func render(template: String) -> PromptRender {
        PromptTemplate.render(template, values: values)
    }
}
