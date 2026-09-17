import Testing
@testable import Core

@Suite("Workspace start context")
struct WorkspaceStartContextTests {
    @Test("A real listing is offered as it is")
    func optionsPassThrough() {
        #expect(
            WorkspaceStartContext.branchOptions(branches: ["main", "wip"], defaultBranch: "main")
                == ["main", "wip"]
        )
    }

    @Test("An empty listing still offers the default branch")
    func optionsFallBackToDefault() {
        #expect(
            WorkspaceStartContext.branchOptions(branches: [], defaultBranch: "main") == ["main"]
        )
    }

    @Test("A choice that survives the listing is kept")
    func currentChoiceSurvives() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "release",
                branches: ["main", "release"],
                defaultBranch: "main"
            ) == "release"
        )
    }

    @Test("A stale choice falls back to the default branch")
    func staleChoiceFallsBackToDefault() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "gone",
                branches: ["main", "wip"],
                defaultBranch: "main"
            ) == "main"
        )
    }

    @Test("A repository without its default branch offers the first branch there is")
    func missingDefaultFallsBackToFirst() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                branches: ["trunk", "wip"],
                defaultBranch: "main"
            ) == "trunk"
        )
    }

    @Test("No branches at all still answers with the default branch")
    func emptyListingAnswersDefault() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                branches: [],
                defaultBranch: "main"
            ) == "main"
        )
    }

    @Test("The empty sheet default never survives a real listing")
    func emptyCurrentIsNeverKept() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                branches: ["main", "wip"],
                defaultBranch: "main"
            ) == "main"
        )
    }
}
