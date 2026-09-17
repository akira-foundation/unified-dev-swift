import Foundation
import Testing
@testable import Core

@Suite("Workspace source picker")
struct WorkspaceSourceTests {
    private func listing(
        number: Int = 12,
        title: String = "Fix the parser",
        author: String = "contributor",
        head: String = "fix-parser",
        isDraft: Bool = false
    ) -> PullRequestListing {
        PullRequestListing(
            number: number,
            title: title,
            author: author,
            headRefName: head,
            baseRefName: "main",
            isDraft: isDraft
        )
    }

    private func offering(
        pullRequests: [PullRequestListing] = [],
        branches: [ExistingBranch] = [],
        baseBranches: [String] = []
    ) -> WorkspaceSourceOffering {
        WorkspaceSourceOffering(
            pullRequests: pullRequests, branches: branches, baseBranches: baseBranches
        )
    }

    @Test("The same branch is offered under both verbs, which is the point of the picker")
    func offersBothVerbs() {
        let matches = offering(
            branches: [ExistingBranch(name: "figma-mcp-check", isLocal: false)],
            baseBranches: ["main", "figma-mcp-check"]
        ).search(query: "figma")
        #expect(matches.open.map(\.name) == ["figma-mcp-check"])
        #expect(matches.new.map(\.name) == ["figma-mcp-check"])
        #expect(matches.open.first?.verb == "Open")
        #expect(matches.new.first?.verb == "New branch from")
    }

    @Test("Only the open verb is a checkout; a new branch is the sheet's own route")
    func namesWhatIsBeingOpened() {
        let branch = ExistingBranch(name: "wip", isLocal: true)
        #expect(WorkspaceSource.existingBranch(branch).checkout == .branch(branch))
        #expect(WorkspaceSource.newBranch(from: "wip").checkout == nil)
        let request = listing()
        #expect(WorkspaceSource.pullRequest(.listed(request)).checkout == .pullRequest(request))
    }

    @Test("Every row is identified by what it names, never by where it sits")
    func identifiesRowsByName() {
        #expect(WorkspaceSource.newBranch(from: "wip").id != WorkspaceSource.existingBranch(
            ExistingBranch(name: "wip", isLocal: true)
        ).id)
    }

    @Test("A pull request is found by its number, its title, its author and its head")
    func findsPullRequestsEveryWayTheyAreRemembered() {
        let offered = offering(pullRequests: [
            listing(number: 41, title: "Serialise the drains", author: "freekmurze", head: "drains"),
            listing(number: 42, title: "Rename the sheet", author: "someone", head: "rename"),
        ])
        #expect(offered.search(query: "drains").open.first?.name == "drains")
        #expect(offered.search(query: "freekmurze").open.first?.name == "drains")
        #expect(offered.search(query: "rename").open.first?.name == "rename")
        #expect(offered.search(query: "serialise").open.first?.name == "drains")
        #expect(offered.search(query: "serialise").open.first?.detail == "#41 Serialise the drains")
    }

    @Test("A branch nothing matches is gone, and so is the whole result when nothing matches")
    func filters() {
        let matches = offering(
            branches: [ExistingBranch(name: "wip", isLocal: true)],
            baseBranches: ["main"]
        ).search(query: "zzz")
        #expect(matches.isEmpty)
        #expect(matches.query == "zzz")
    }

    @Test("An empty query offers everything, pull requests before branches")
    func offersEverythingWhenNothingIsTyped() {
        let matches = offering(
            pullRequests: [listing(number: 7)],
            branches: [ExistingBranch(name: "wip", isLocal: true)],
            baseBranches: ["main", "wip"]
        ).search(query: "  ")
        #expect(matches.open.count == 2)
        #expect(matches.open.first?.name == "fix-parser")
        #expect(matches.new.map(\.name) == ["main", "wip"])
    }

    @Test("The list is capped, so a repository with a thousand branches is still a panel")
    func capsEachSection() {
        let many = (1...200).map { "branch-\($0)" }
        let matches = offering(baseBranches: many).search(query: "", limit: 5)
        #expect(matches.new.count == 5)
    }

    @Test("A typed number is offered as a pull request to look up")
    func offersATypedNumber() {
        let matches = offering(baseBranches: ["main"]).search(query: "1234")
        #expect(matches.open.first?.name == "#1234")
        guard case .pullRequest(.typed(let reference, let text)) = matches.open.first else {
            Issue.record("the typed number was not offered as a pull request")
            return
        }
        #expect(reference.number == 1234)
        #expect(text == "1234")
    }

    @Test("A pasted URL keeps the repository it named")
    func offersATypedURL() {
        let matches = offering().search(query: "https://github.com/akira-io/ray/pull/7/files")
        guard case .pullRequest(.typed(let reference, let text)) = matches.open.first else {
            Issue.record("the pasted URL was not offered as a pull request")
            return
        }
        #expect(reference.number == 7)
        #expect(reference.repository == "akira-io/ray")
        #expect(text.contains("akira-io/ray"))
    }

    @Test("A number the list already answers is not offered twice")
    func prefersTheListedPullRequest() {
        let matches = offering(pullRequests: [listing(number: 42)]).search(query: "42")
        #expect(matches.open.count == 1)
        #expect(matches.open.first?.checkout != nil)
    }

    @Test("A branch name is not a pull request number")
    func doesNotOfferNonsenseAsAPullRequest() {
        let matches = offering(baseBranches: ["main"]).search(query: "main")
        #expect(matches.open.isEmpty)
        #expect(matches.new.map(\.name) == ["main"])
    }

    @Test("An in-use branch is listed, greyed by its note, and says which workspace has it")
    func marksAnInUseBranch() {
        let row = WorkspaceSource.existingBranch(
            ExistingBranch(name: "review", isLocal: true, inUseBy: .workspace("Quiet Harbour"))
        )
        #expect(row.heldBy == .workspace("Quiet Harbour"))
        #expect(row.note == "In use by Quiet Harbour")
        let remote = WorkspaceSource.existingBranch(
            ExistingBranch(name: "review", isLocal: false, inUseBy: .workspace("Quiet Harbour"))
        )
        #expect(remote.note == "In use by Quiet Harbour")
        #expect(
            WorkspaceSource.existingBranch(ExistingBranch(name: "review", isLocal: false)).note
                == "remote"
        )
        #expect(WorkspaceSource.newBranch(from: "main").heldBy == nil)
    }

    @Test("A draft and its author are what a pull request row says after its title")
    func notesADraft() {
        #expect(
            WorkspaceSource.pullRequest(.listed(listing(author: "freekmurze", isDraft: true))).note
                == "draft, freekmurze"
        )
        #expect(
            WorkspaceSource.pullRequest(.listed(listing(author: ""))).note == nil
        )
    }

    @Test("Down and up walk the visible tab, and wrap inside it")
    func stepsThroughTheVisibleTab() {
        let matches = offering(
            branches: [ExistingBranch(name: "wip", isLocal: true), ExistingBranch(name: "old", isLocal: true)],
            baseBranches: ["main"]
        ).search(query: "")
        let rows = matches.rows(in: .existingBranch)
        let first = rows.first
        let last = rows.last
        #expect(first != last)
        #expect(matches.stepped(from: nil, by: 1, in: .existingBranch) == first)
        #expect(matches.stepped(from: nil, by: -1, in: .existingBranch) == last)
        #expect(matches.stepped(from: first, by: 1, in: .existingBranch) == last)
        #expect(matches.stepped(from: last, by: 1, in: .existingBranch) == first)
        #expect(WorkspaceSourceMatches().stepped(from: nil, by: 1, in: .newBranch) == nil)
    }

    @Test("The keyboard cannot step out of the tab that is on screen")
    func doesNotStepIntoTheHiddenTab() {
        let matches = offering(
            branches: [ExistingBranch(name: "wip", isLocal: true)],
            baseBranches: ["main"]
        ).search(query: "")
        let newRows = matches.rows(in: .newBranch)
        #expect(newRows.count == 1)
        #expect(matches.stepped(from: newRows.first, by: 1, in: .newBranch) == newRows.first)
        #expect(matches.stepped(from: newRows.first, by: -1, in: .newBranch) == newRows.first)
        #expect(matches.rows(in: .existingBranch).contains(newRows[0]) == false)
    }

    @Test("A pull request whose head gh did not answer keeps its number and title")
    func fallsBackWhenThereIsNoHead() {
        let row = WorkspaceSource.pullRequest(.listed(
            listing(number: 88, title: "Teach it to wait", head: "")
        ))
        #expect(row.name == "#88 Teach it to wait")
        #expect(row.detail == nil)
    }

    @Test("A fork's head is qualified by its owner, because a bare name is somebody else's branch")
    func qualifiesAForkHead() {
        let fork = PullRequestListing(
            number: 91,
            title: "Add the thing",
            author: "stranger",
            headRefName: "patch-1",
            baseRefName: "main",
            isCrossRepository: true,
            headRepositoryOwner: "stranger"
        )
        #expect(WorkspaceSource.pullRequest(.listed(fork)).name == "stranger:patch-1")
        #expect(WorkspaceCheckoutPlan.heads(of: [fork]).contains("patch-1") == false)
    }

    @Test("Each row knows which tab it belongs under")
    func sortsRowsIntoTabs() {
        #expect(WorkspaceSource.newBranch(from: "main").tab == .newBranch)
        #expect(WorkspaceSource.existingBranch(ExistingBranch(name: "wip", isLocal: true)).tab
            == .existingBranch)
        #expect(WorkspaceSource.pullRequest(.listed(listing())).tab == .existingBranch)
    }

    @Test("Stepping a tab wraps, so one key reaches the other tab from either")
    func stepsBetweenTabs() {
        #expect(WorkspaceSourceTab.newBranch.stepped(by: 1) == .existingBranch)
        #expect(WorkspaceSourceTab.newBranch.stepped(by: -1) == .existingBranch)
        #expect(WorkspaceSourceTab.existingBranch.stepped(by: 1) == .newBranch)
    }

    @Test("A highlight that the next keystroke filters away moves to the best row there is")
    func settlesTheHighlight() {
        let offered = offering(
            branches: [ExistingBranch(name: "wip", isLocal: true)],
            baseBranches: ["main", "wip"]
        )
        let held = WorkspaceSource.existingBranch(ExistingBranch(name: "wip", isLocal: true))
        #expect(offered.search(query: "wip").settled(after: held, in: .existingBranch) == held)
        #expect(offered.search(query: "main").settled(after: held, in: .newBranch)?.name == "main")
        #expect(WorkspaceSourceMatches().settled(after: held, in: .existingBranch) == nil)
        #expect(offered.search(query: "").settled(after: held, in: .newBranch)?.name == "main")
    }

    @Test("Cutting from a free branch offers to open that branch instead")
    func offersToOpenAFreeBranch() {
        let branch = ExistingBranch(name: "wip", isLocal: true)
        let offer = offering(branches: [branch], baseBranches: ["main", "wip"]).carryOn(from: "wip")
        #expect(offer?.source == .existingBranch(branch))
        #expect(offer?.action == "Open wip instead")
        #expect(offer?.sentence == "This cuts a new branch from wip.")
    }

    @Test("Cutting from the default branch, or from one nobody can open, offers nothing")
    func offersNothingForTheOrdinaryCase() {
        let offered = offering(
            branches: [
                ExistingBranch(name: "mine", isLocal: true, inUseBy: .projectCheckout(path: "/p")),
                ExistingBranch(name: "theirs", isLocal: true, inUseBy: .otherWorktree(path: "/c")),
            ],
            baseBranches: ["main", "mine", "theirs"]
        )
        #expect(offered.carryOn(from: "main") == nil)
        #expect(offered.carryOn(from: "") == nil)
        #expect(offered.carryOn(from: "mine") == nil)
        #expect(offered.carryOn(from: "theirs") == nil)
    }

    @Test("A branch one of Unified Dev's workspaces holds offers to go there")
    func offersTheWorkspaceHoldingTheBranch() {
        let branch = ExistingBranch(name: "wip", isLocal: true, inUseBy: .workspace("Quiet Harbour"))
        let offer = offering(branches: [branch], baseBranches: ["wip"]).carryOn(from: "wip")
        #expect(offer?.source == .existingBranch(branch))
        #expect(offer?.action == "Go to Quiet Harbour")
    }

    @Test("A pull request on the branch answers before the bare branch, and forks do not count")
    func prefersThePullRequestOnTheBranch() {
        let request = listing(number: 5, head: "fix-parser")
        let offered = offering(pullRequests: [request], baseBranches: ["fix-parser"])
        #expect(offered.carryOn(from: "fix-parser")?.source == .pullRequest(.listed(request)))
        let checkedOut: [String: BranchHolder] = ["fix-parser": .projectCheckout(path: "/p")]
        #expect(offered.carryOn(from: "fix-parser", holders: checkedOut) == nil)

        let fork = PullRequestListing(
            number: 6, title: "Patch", headRefName: "patch-1", baseRefName: "main",
            isCrossRepository: true, headRepositoryOwner: "stranger"
        )
        #expect(offering(pullRequests: [fork], baseBranches: ["patch-1"]).carryOn(from: "patch-1") == nil)
    }

    @Test("The button says 'on' for a checkout and 'from' for a new branch")
    func labelsTheButton() {
        #expect(WorkspaceSource.label(for: nil, baseBranch: "main") == "from main")
        #expect(
            WorkspaceSource.label(
                for: .branch(ExistingBranch(name: "figma-mcp-check", isLocal: false)),
                baseBranch: "main"
            ) == "on figma-mcp-check"
        )
        #expect(
            WorkspaceSource.label(for: .pullRequest(listing(head: "fix-parser")), baseBranch: "main")
                == "on fix-parser"
        )
    }
}
