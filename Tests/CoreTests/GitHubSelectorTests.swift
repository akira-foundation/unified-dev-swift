import Testing
@testable import Core

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
