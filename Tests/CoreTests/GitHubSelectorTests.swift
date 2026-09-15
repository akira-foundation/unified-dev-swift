import Testing
@testable import Core

/// What may and may not have `--repo` put on it.
///
/// **The bug these are written from.** The inspector showed "GitHub could not refresh" over eleven
/// lines of gh's own usage text, and the first line of it was
/// "`gh pr view` exited 1: argument required when using the --repo flag". `pr view` with no
/// number, url or branch is a deliberate call: it is the only one that resolves a pull request
/// from a forked head, through the `refs/pull/N/head` config `gh pr checkout` writes, and
/// `GitHub.snapshotOfCheckedOutBranch` says so at length. Adding `--repo` to it takes the local
/// checkout out of the answer, which is exactly what that call depends on, and gh refuses rather
/// than guessing.
@Suite("gh selectors")
struct GitHubSelectorTests {
    private var context: GitRepositoryContext {
        GitRepositoryContext.resolve(config: [
            "remote.origin.url": "git@github.com:person/project.git",
        ], base: "main", branch: "feature")
    }

    @Test("pr view with no selector is left alone")
    func viewWithoutSelector() {
        #expect(GitHub.repositoryArguments(["pr", "view", "--json", "number"], context: context)
            == ["pr", "view", "--json", "number"])
    }

    @Test("pr view with a selector still names the repository")
    func viewWithSelector() {
        #expect(GitHub.repositoryArguments(["pr", "view", "123", "--json", "number"], context: context)
            == ["pr", "view", "123", "--json", "number", "--repo", "github.com/person/project"])
        #expect(GitHub.repositoryArguments(["pr", "view", "feature"], context: context)
            == ["pr", "view", "feature", "--repo", "github.com/person/project"])
    }

    @Test("every other pr command still names the repository")
    func otherCommands() {
        #expect(GitHub.repositoryArguments(["pr", "list", "--json", "number"], context: context)
            == ["pr", "list", "--json", "number", "--repo", "github.com/person/project"])
        #expect(GitHub.repositoryArguments(["pr", "checkout", "123"], context: context)
            == ["pr", "checkout", "123", "--repo", "github.com/person/project"])
    }
}
