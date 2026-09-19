import Foundation

public struct RepositoryCheck: Sendable, Equatable {
    public var path: String
    public var problem: GitRepositoryProblem?

    public init(path: String, problem: GitRepositoryProblem?) {
        self.path = path
        self.problem = problem
    }

    public static func asking(gitAbout path: String) async -> RepositoryCheck {
        RepositoryCheck(path: path, problem: await NewProjectStarter.repositoryProblem(at: path))
    }

    public func applied(to facts: NewProjectFacts) -> NewProjectFacts {
        guard facts.path == path else { return facts }
        var checked = facts
        checked.gitProblem = problem
        return checked
    }
}
