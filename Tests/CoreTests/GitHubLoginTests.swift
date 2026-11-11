import Testing
import Foundation
@testable import Core

@Suite("A profile's GitHub login")
struct GitHubLoginTests {
    private let root = URL(filePath: "/support/GitHubLogins", directoryHint: .isDirectory)
    private let debtges = ProfileID("debtges")

    @Test func unifiedAlwaysUsesThisMacsLogin() {
        let logins = ProfileGitHubLogins(sources: [.initial: .own], root: root)
        #expect(logins.source(of: .initial) == .inherits)
        #expect(logins.login(for: .initial) == .thisMac)
    }

    @Test func aProfileUsesUnifiedsLoginUntilToldOtherwise() {
        let logins = ProfileGitHubLogins(root: root)
        #expect(logins.source(of: debtges) == .inherits)
        #expect(logins.login(for: debtges) == .thisMac)
        #expect(logins.login(for: nil) == .thisMac)
    }

    @Test func aProfileWithItsOwnLoginHasADirectoryNamedAfterIt() {
        let logins = ProfileGitHubLogins(sources: [debtges: .own], root: root)
        let login = logins.login(for: debtges)
        #expect(login == .profile(debtges, directory: root.appending(path: "debtges", directoryHint: .isDirectory)))
        #expect(login.directory?.path == "/support/GitHubLogins/debtges")
    }

    @Test func thisMacsLoginLeavesTheEnvironmentAlone() {
        let inherited = ["GH_TOKEN": "inherited", "PATH": "/bin"]
        #expect(GitHubLogin.thisMac.variables.isEmpty)
        #expect(GitHubLogin.thisMac.applied(to: inherited) == inherited)
    }

    @Test func anOwnLoginNamesItsDirectoryAndSilencesEveryTokenVariable() {
        let login = GitHubLogin.profile(debtges, directory: root.appending(path: "debtges"))
        let variables = login.variables
        #expect(variables["GH_CONFIG_DIR"] == "/support/GitHubLogins/debtges")
        for name in ["GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"] {
            #expect(variables[name] == "")
        }

        let applied = login.applied(to: ["GH_TOKEN": "a", "GITHUB_TOKEN": "b", "GH_ENTERPRISE_TOKEN": "c", "PATH": "/bin"])
        #expect(applied == ["GH_CONFIG_DIR": "/support/GitHubLogins/debtges", "PATH": "/bin"])
    }

    @Test func theSignInCommandToCopyNamesTheProfilesDirectory() {
        let login = GitHubLogin.profile(debtges, directory: URL(filePath: "/support/it's here", directoryHint: .isDirectory))
        #expect(login.signInCommand == #"GH_CONFIG_DIR='/support/it'\''s here' gh auth login"#)
        #expect(GitHubLogin.thisMac.signInCommand == "gh auth login")
    }

    @Test func aDirectoryBelongsToTheProfileOfTheWorkspaceOrProjectHoldingIt() {
        let site = Repo(name: "site", path: "/code/site", profileID: debtges)
        let app = Repo(name: "app", path: "/code/app", profileID: .initial)
        let worktree = Workspace(
            repoID: site.id, name: "w", branch: "feature/w", path: "/worktrees/debtges/site/w", baseBranch: "main"
        )
        let routes = GitHubLoginRoutes(repos: [site, app], workspaces: [worktree])

        #expect(routes.profile(forDirectory: "/code/site") == debtges)
        #expect(routes.profile(forDirectory: "/code/site/Sources/") == debtges)
        #expect(routes.profile(forDirectory: "/worktrees/debtges/site/w") == debtges)
        #expect(routes.profile(forDirectory: "/code/app") == .initial)
        #expect(routes.profile(forDirectory: "/code/site-2") == nil)
        #expect(routes.profile(forDirectory: "/elsewhere") == nil)
        #expect(routes.profile(forDirectory: "") == nil)
    }

    @Test func theDeepestPathDecidesWhenOneHoldsAnother() {
        let routes = GitHubLoginRoutes(routes: [
            .init(path: "/code", profile: .initial),
            .init(path: "/code/site/", profile: debtges),
        ])
        #expect(routes.profile(forDirectory: "/code/site/w") == debtges)
        #expect(routes.profile(forDirectory: "/code/other") == .initial)
    }

    @Test func theFootnoteSaysWhichLoginAProfileUses() {
        let inherits = ProfileGitHubWording.footnote(source: .inherits, isInitial: false, profileName: "Debtges", user: "octo")
        #expect(inherits.contains("Unified's GitHub login") && inherits.contains("octo"))

        let signedOut = ProfileGitHubWording.footnote(source: .own, isInitial: false, profileName: "Debtges", user: nil)
        #expect(signedOut.contains("never use this Mac's login"))

        let own = ProfileGitHubWording.footnote(source: .own, isInitial: false, profileName: "Debtges", user: "client-bot")
        #expect(own.contains("run as client-bot"))
    }
}
