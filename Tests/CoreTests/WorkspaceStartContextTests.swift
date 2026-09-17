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
                local: ["main", "release"],
                remote: [],
                defaultBranch: "main"
            ) == "release"
        )
    }

    @Test("A stale choice falls back to the default branch")
    func staleChoiceFallsBackToDefault() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "gone",
                local: ["main", "wip"],
                remote: [],
                defaultBranch: "main"
            ) == "main"
        )
    }

    @Test("A repository without its default branch offers the first branch there is")
    func missingDefaultFallsBackToFirst() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                local: ["trunk", "wip"],
                remote: [],
                defaultBranch: "main"
            ) == "trunk"
        )
    }

    @Test("No branches at all still answers with the default branch")
    func emptyListingAnswersDefault() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                local: [],
                remote: [],
                defaultBranch: "main"
            ) == "main"
        )
    }

    @Test("The empty sheet default never survives a real listing")
    func emptyCurrentIsNeverKept() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                local: ["main", "wip"],
                remote: [],
                defaultBranch: "main"
            ) == "main"
        )
    }

    @Test("A branch only the remote has is offered as a base, once, in order")
    func remoteOnlyBranchesAreBases() {
        #expect(
            WorkspaceStartContext.baseBranchOptions(
                local: ["main", "wip"],
                remote: ["main", "colleague/idea", "wip"],
                defaultBranch: "main"
            ) == ["colleague/idea", "main", "wip"]
        )
    }

    @Test("Only the primary remote's branches are offered, origin first")
    func primaryRemoteOnly() {
        let references = ["origin", "origin/main", "origin/idea", "upstream/elsewhere"]
        #expect(
            WorkspaceStartContext.primaryRemoteBranches(
                references: references, remoteNames: ["upstream", "origin"]
            ) == ["main", "idea"]
        )
        #expect(
            WorkspaceStartContext.primaryRemoteBranches(
                references: ["github/main"], remoteNames: ["github"]
            ) == ["main"]
        )
        #expect(
            WorkspaceStartContext.primaryRemoteBranches(references: [], remoteNames: []).isEmpty
        )
    }

    @Test("No branches on either side still offers the default branch")
    func noBasesFallBackToDefault() {
        #expect(
            WorkspaceStartContext.baseBranchOptions(local: [], remote: [], defaultBranch: "main")
                == ["main"]
        )
    }

    @Test("An empty name on either side is never offered")
    func emptyNamesAreDropped() {
        #expect(
            WorkspaceStartContext.baseBranchOptions(local: ["", "main"], remote: [""], defaultBranch: "main")
                == ["main"]
        )
    }

    @Test("A base only the remote has survives the sheet reloading")
    func remoteOnlyChoiceSurvivesAReload() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "colleague/idea",
                local: ["main"],
                remote: ["colleague/idea", "main"],
                defaultBranch: "main"
            ) == "colleague/idea"
        )
    }

    @Test("With the default branch gone, a local branch is preferred over a remote one")
    func fallbackPrefersALocalBranch() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                local: ["trunk"],
                remote: ["dependabot/npm/lodash"],
                defaultBranch: "main"
            ) == "trunk"
        )
    }

    @Test("With nothing local left, the first remote name is the last resort")
    func fallbackReachesTheRemote() {
        #expect(
            WorkspaceStartContext.resolvedBaseBranch(
                current: "",
                local: [],
                remote: ["colleague/idea", "wip"],
                defaultBranch: "main"
            ) == "colleague/idea"
        )
    }
}
