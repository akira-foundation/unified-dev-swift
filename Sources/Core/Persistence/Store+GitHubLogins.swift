import Foundation

extension Store {
    public nonisolated func gitHubLogins() -> ProfileGitHubLogins {
        gitHubLoginBook.withLock { $0 }
    }

    public nonisolated func gitHubLogin(for profile: ProfileID?) -> GitHubLogin {
        gitHubLogins().login(for: profile)
    }

    public func gitHubLogin(forDirectory directory: String) throws -> GitHubLogin {
        let routes = GitHubLoginRoutes(repos: try repos(), workspaces: try workspaces(includeArchived: true))
        return gitHubLogins().login(forDirectory: directory, routes: routes)
    }

    public func setGitHubSource(_ source: ProfileGitHubSource, for profile: ProfileID) throws {
        guard profile != .initial else { return }
        try writeGitHubSource(source, for: profile)
    }
}
