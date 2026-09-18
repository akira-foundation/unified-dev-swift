import Foundation
import Testing
@testable import Core

@Suite("Worktree listing", .scratchDirectory)
struct WorktreeListingTests {
    static let thereThere = """
        worktree /Users/freek/dev/code/there-there
        HEAD 67bfc360dad6fea4dcecb3964c027b0800bb0801
        branch refs/heads/main

        worktree /Users/freek/unifieddev/workspaces/there-there/freekmurze-mawson-sea
        HEAD ba5d665bd1d21692e8bd4c24e59bd74889d58338
        branch refs/heads/freekmurze/review-changes

        worktree /Users/freek/unifieddev/workspaces/there-there/freekmurze-molucca-sea
        HEAD ba5d665bd1d21692e8bd4c24e59bd74889d58338
        branch refs/heads/freekmurze/review-repo-changes

        worktree /Users/freek/conductor/workspaces/there-there/adelaide
        HEAD ba5d665bd1d21692e8bd4c24e59bd74889d58338
        branch refs/heads/freekmurze/figma-mcp-check

        worktree /Users/freek/conductor/workspaces/there-there/port-louis
        HEAD 9a5419ea7120db9a74ae0486c9b19f808d9cdc90
        branch refs/heads/freekmurze/investigate-ticket-issues

        worktree /Users/freek/orca/workspaces/there-there/anglerfish
        HEAD a870d24b0287a3f9c7c3273d54a9a970c4d0bc82
        branch refs/heads/freekmurze/delete-ticket-workflow-crash

        """

    static let unifieddev = """
        worktree /Users/freek/dev/code/unifieddev
        HEAD 7c28676194979a756ff1ec3987b75bf9e6eb1e04
        branch refs/heads/feat/quick-prompt-icon-picker

        worktree /Users/freek/dev/code/unifieddev/.claude/worktrees/agent-a027934bc60df6d12
        HEAD 97c58990967b1f091feac9de1d019b28edabcbca
        branch refs/heads/docs/audit-fixes

        worktree /Users/freek/dev/code/unifieddev/.claude/worktrees/agent-a2f34e223cc574ba6
        HEAD 4d885856a5ee18427ed0d771bbf6b76c116dfcc2
        branch refs/heads/swiftlint
        locked claude agent agent-a2f34e223cc574ba6 (pid 2545 start Mon Aug 24 13:40:21 2026)

        """

    @Test("every record of a real listing is read, in the order git printed them")
    func readsARealListing() {
        let entries = WorktreeListing.parse(Self.thereThere)
        #expect(entries.count == 6)
        #expect(entries.first?.path == "/Users/freek/dev/code/there-there")
        #expect(entries.first?.branch == "main")
        #expect(entries.last?.path == "/Users/freek/orca/workspaces/there-there/anglerfish")
    }

    @Test("a branch is the full ref with refs/heads/ taken off and nothing else")
    func keepsSlashesInsideABranchName() {
        let entries = WorktreeListing.parse(Self.thereThere)
        let adelaide = entries.first { $0.path.hasSuffix("/adelaide") }
        #expect(adelaide?.branch == "freekmurze/figma-mcp-check")
        #expect(adelaide?.head == "ba5d665bd1d21692e8bd4c24e59bd74889d58338")
    }

    @Test("a locked worktree carries its reason and still holds its branch")
    func readsALockedWorktree() {
        let entries = WorktreeListing.parse(Self.unifieddev)
        let locked = entries.first { $0.branch == "swiftlint" }
        #expect(locked?.isLocked == true)
        #expect(locked?.lockReason?.hasPrefix("claude agent agent-a2f34e223cc574ba6") == true)
        #expect(entries.first { $0.branch == "docs/audit-fixes" }?.isLocked == false)
    }

    @Test("bare, detached and prunable records are read for what they are")
    func readsTheAwkwardRecords() {
        let entries = WorktreeListing.parse("""
            worktree /Users/freek/mirrors/unifieddev.git
            bare

            worktree /Users/freek/looking/at/a/tag
            HEAD 623188465f198b813d32b4520e43b4e8f84aa2ab
            detached

            worktree /Users/freek/gone
            HEAD 623188465f198b813d32b4520e43b4e8f84aa2ab
            branch refs/heads/left-behind
            prunable gitdir file points to non-existent location

            worktree /Users/freek/locked/without/a/reason
            HEAD 623188465f198b813d32b4520e43b4e8f84aa2ab
            branch refs/heads/parked
            locked
            """)
        #expect(entries.count == 4)
        #expect(entries[0].isBare)
        #expect(entries[0].branch == nil)
        #expect(entries[1].isDetached)
        #expect(entries[1].branch == nil)
        #expect(entries[2].isPrunable)
        #expect(entries[2].pruneReason == "gitdir file points to non-existent location")
        #expect(entries[3].lockReason == "")
        #expect(entries[3].isLocked)
    }

    @Test("a path with spaces in it survives, and the last record needs no blank line after it")
    func readsAPathWithSpaces() {
        let entries = WorktreeListing.parse("""
            worktree /Users/freek/My Projects/there there
            HEAD 67bfc360dad6fea4dcecb3964c027b0800bb0801
            branch refs/heads/main
            """)
        #expect(entries.map(\.path) == ["/Users/freek/My Projects/there there"])
    }

    @Test("a missing blank line does not merge two worktrees into one")
    func survivesAMissingSeparator() {
        let entries = WorktreeListing.parse("""
            worktree /a
            HEAD 1111111111111111111111111111111111111111
            branch refs/heads/one
            worktree /b
            HEAD 2222222222222222222222222222222222222222
            branch refs/heads/two
            """)
        #expect(entries.map(\.path) == ["/a", "/b"])
        #expect(entries.map(\.branch) == ["one", "two"])
    }

    @Test("git's own output, read back out of a repository with a second worktree in it")
    func readsARepositoryOnThisMachine() async throws {
        let repo = try await TempRepo(defaultBranch: "main")
        defer { repo.cleanUp() }
        let second = TestScratch.unique("held")
        try await Git.addWorktree(repo: repo.path, path: second, branch: "feature", base: "main")
        defer { try? FileManager.default.removeItem(atPath: second) }

        let entries = try await Git.worktrees(of: repo.path)
        #expect(entries.count == 2)
        #expect(entries.contains { $0.branch == "main" })
        #expect(entries.contains { $0.branch == "feature" })

        let holders = BranchHolder.byBranch(worktrees: entries, projectPath: repo.path)
        #expect(holders["feature"]?.isAppWorkspace == false)
        if case .projectCheckout = holders["main"] {} else {
            Issue.record("the repository's own checkout was read as something else")
        }
        let refused = await #expect(throws: (any Error).self) {
            try await Git.addWorktree(
                repo: repo.path, path: TestScratch.unique("third"), branch: "feature", base: "main"
            )
        }
        #expect("\(refused!)".contains("already used by worktree"))
    }

    @Test("nothing at all is no worktrees rather than one empty one")
    func readsNothing() {
        #expect(WorktreeListing.parse("").isEmpty)
        #expect(WorktreeListing.parse("\n\n").isEmpty)
        #expect(WorktreeListing.parse("HEAD 1111111111111111111111111111111111111111").isEmpty)
    }
}

@Suite("Branch holders", .scratchDirectory)
struct BranchHolderTests {
    private var thereThere: [WorktreeEntry] {
        WorktreeListing.parse(WorktreeListingTests.thereThere)
    }

    @Test("a worktree Unified Dev did not make holds its branch just as firmly")
    func seesAWorktreeFromAnotherApplication() {
        let holders = BranchHolder.byBranch(
            worktrees: thereThere,
            projectPath: "/Users/freek/dev/code/there-there",
            workspaceNames: ["freekmurze/review-changes": "Mawson Sea"]
        )
        #expect(
            holders["freekmurze/figma-mcp-check"]
                == .otherWorktree(path: "/Users/freek/conductor/workspaces/there-there/adelaide")
        )
        #expect(holders["freekmurze/review-changes"] == .workspace("Mawson Sea"))
        #expect(
            holders["freekmurze/review-repo-changes"]
                == .otherWorktree(
                    path: "/Users/freek/unifieddev/workspaces/there-there/freekmurze-molucca-sea"
                )
        )
        #expect(holders["nothing-has-this"] == nil)
    }

    @Test("the project's own checkout is not another tool holding the branch")
    func tellsTheMainCheckoutApart() {
        let holders = BranchHolder.byBranch(
            worktrees: thereThere, projectPath: "/Users/freek/dev/code/there-there"
        )
        #expect(holders["main"] == .projectCheckout(path: "/Users/freek/dev/code/there-there"))
        #expect(holders["main"]?.note == "Checked out in the project")
    }

    @Test("a trailing slash or a dot in the project's path is still the project's path")
    func comparesPathsRatherThanStrings() {
        for path in [
            "/Users/freek/dev/code/there-there/",
            "/Users/freek/dev/code/./there-there",
            "/Users/freek/dev/code/unifieddev/../there-there",
        ] {
            let holders = BranchHolder.byBranch(worktrees: thereThere, projectPath: path)
            #expect(holders["main"]?.isAppWorkspace == false)
            if case .projectCheckout = holders["main"] {} else {
                Issue.record("\(path) was not recognised as the project's own checkout")
            }
        }
    }

    @Test("a bare record and a detached head hold no branch")
    func ignoresWhatHoldsNoBranch() {
        let holders = BranchHolder.byBranch(
            worktrees: [
                WorktreeEntry(path: "/mirror", isBare: true),
                WorktreeEntry(path: "/tag", head: "abc", isDetached: true),
                WorktreeEntry(path: "/real", head: "abc", branch: "feature"),
            ],
            projectPath: "/project"
        )
        #expect(holders.count == 1)
        #expect(holders["feature"] == .otherWorktree(path: "/real"))
    }

    @Test("only this project's live workspaces supply a name")
    func namesOnlyLiveWorkspacesOfThisProject() {
        let mine = RepoID("there-there")
        let theirs = RepoID("unifieddev")
        var archived = Workspace(
            repoID: mine, name: "Old", branch: "gone", path: "/tmp/a", baseBranch: "main"
        )
        archived.state = .archived
        let names = BranchHolder.names(
            of: [
                archived,
                Workspace(
                    repoID: mine, name: "Mawson Sea", branch: "freekmurze/review-changes",
                    path: "/tmp/b", baseBranch: "main"
                ),
                Workspace(
                    repoID: theirs, name: "Elsewhere", branch: "develop",
                    path: "/tmp/c", baseBranch: "main"
                ),
            ],
            in: mine
        )
        #expect(names == ["freekmurze/review-changes": "Mawson Sea"])
    }

    @Test("the row says which kind of holder it is without printing a path")
    func notesReadDifferently() {
        #expect(BranchHolder.workspace("Quiet Harbour").note == "In use by Quiet Harbour")
        #expect(BranchHolder.otherWorktree(path: "/Users/freek/conductor/workspaces/x/adelaide")
            .note == "Checked out elsewhere")
        #expect(!BranchHolder.otherWorktree(path: "/tmp/x").note.contains("/"))
        #expect(BranchHolder.workspace("Quiet Harbour").isAppWorkspace)
        #expect(!BranchHolder.otherWorktree(path: "/tmp/x").isAppWorkspace)
        #expect(!BranchHolder.projectCheckout(path: "/tmp/x").isAppWorkspace)
    }

    @Test("the refusal names the holder and offers the way out")
    func refusalNamesTheHolderAndTheOffer() {
        let conductor = BranchHolder.otherWorktree(
            path: "/Users/freek/conductor/workspaces/there-there/adelaide"
        )
        let sentence = conductor.refusal(branch: "freekmurze/figma-mcp-check")
        #expect(sentence.contains("/Users/freek/conductor/workspaces/there-there/adelaide"))
        #expect(sentence.contains("freekmurze/figma-mcp-check"))
        #expect(sentence.contains("New branch from"))
        #expect(!sentence.contains("128"))
        #expect(!sentence.contains("--force"))

        let ours = BranchHolder.workspace("Quiet Harbour").refusal(branch: "review")
        #expect(ours.contains("'Quiet Harbour'"))
        #expect(!ours.contains("/"))
        #expect(ours.contains("New branch from"))
    }

    @Test("the thrown error says the same thing on its own")
    func theErrorDescribesItself() {
        let error = BranchInUse(
            branch: "freekmurze/figma-mcp-check",
            holder: .otherWorktree(path: "/Users/freek/conductor/workspaces/there-there/adelaide")
        )
        #expect(error.description == error.holder.refusal(branch: error.branch))
        #expect((error as any Error).readableMessage.contains("adelaide"))
    }

    @Test("creating turns the thrown refusal into the owner's sentence")
    func troubleDiagnosesTheRefusal() async {
        let trouble = await WorkspaceTrouble.creating(
            BranchInUse(
                branch: "freekmurze/figma-mcp-check",
                holder: .otherWorktree(
                    path: "/Users/freek/conductor/workspaces/there-there/adelaide"
                )
            ),
            project: "there-there",
            projectPath: "/Users/freek/nowhere-at-all",
            baseBranch: "main"
        )
        guard case let .createBranchInUse(branch, holder) = trouble else {
            Issue.record("expected createBranchInUse, got \(trouble)")
            return
        }
        #expect(branch == "freekmurze/figma-mcp-check")
        #expect(holder == .otherWorktree(path: "/Users/freek/conductor/workspaces/there-there/adelaide"))
        #expect(trouble.sentence.contains("/Users/freek/conductor/workspaces/there-there/adelaide"))
        #expect(trouble.sentence.contains("Nothing has been created"))
        #expect(trouble.sentence.contains("Create new branch"))
        #expect(!trouble.sentence.lowercased().contains("exit status"))
    }
}
