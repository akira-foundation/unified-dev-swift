import CoreGraphics
import Foundation
import Testing
@testable import Core

@Suite("Workspace hover card")
struct WorkspaceHoverCardTests {
    static let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func workspace(
        name: String = "Add a hover card to the sidebar",
        branch: String = "freek/hover-card",
        additions: Int = 0,
        deletions: Int = 0,
        changedFiles: Int = 0,
        unread: Bool = false,
        lastActivityAt: Date = WorkspaceHoverCardTests.now
    ) -> Workspace {
        Workspace(
            repoID: RepoID("repo"),
            name: name,
            branch: branch,
            path: "/tmp/worktree",
            baseBranch: "main",
            createdAt: lastActivityAt,
            lastActivityAt: lastActivityAt,
            additions: additions,
            deletions: deletions,
            changedFiles: changedFiles,
            unread: unread
        )
    }

    private func pullRequest(
        number: Int = 362,
        state: String = "OPEN",
        checks: PullRequest.Checks = .none,
        checksSummary: String = "",
        isDraft: Bool = false
    ) -> PullRequest {
        PullRequest(
            number: number,
            title: "Add a hover card to the sidebar",
            url: "https://github.com/akira-io/unifieddev/pull/\(number)",
            state: state,
            isDraft: isDraft,
            checks: checks,
            checksSummary: checksSummary
        )
    }

    @Test("A changed workspace with no pull request says so and shows its counts")
    func changedWithoutPullRequest() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(additions: 1_418, deletions: 556, changedFiles: 12),
            now: Self.now
        )

        #expect(card.title == "Add a hover card to the sidebar")
        #expect(card.branch == "freek/hover-card")
        #expect(card.diff == WorkspaceHoverCard.Diff(additions: 1_418, deletions: 556))
        #expect(card.status == .changed)
        #expect(card.state == "Has changes")
        #expect(card.detail == nil)
        #expect(card.pullRequest == nil)
    }

    @Test("A workspace with nothing changed carries no counts at all")
    func noChanges() {
        let card = WorkspaceHoverCard.make(workspace: workspace(), now: Self.now)

        #expect(card.diff == nil)
        #expect(card.status == .clean)
        #expect(card.state == "No changes")
    }

    @Test("Changed files with no changed lines draw no counts")
    func zeroLineDiff() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(changedFiles: 2), now: Self.now
        )

        #expect(card.status == .clean)
        #expect(card.diff == nil)
    }

    @Test("Failing checks put the count behind the state rather than in place of it")
    func failingChecks() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(additions: 40, deletions: 3, changedFiles: 2),
            pullRequest: pullRequest(
                checks: .failing, checksSummary: "1 of 12 checks failed"
            ),
            now: Self.now
        )

        #expect(card.status == .checksFailing)
        #expect(card.state == "Checks failing")
        #expect(card.detail == "1 of 12 checks failed")
        #expect(card.pullRequest?.number == 362)
        #expect(card.pullRequest?.url == "https://github.com/akira-io/unifieddev/pull/362")
    }

    @Test("A rollup summary equal to the state is not repeated under it")
    func detailThatRepeatsTheState() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(additions: 40, deletions: 3, changedFiles: 2),
            pullRequest: pullRequest(checks: .failing, checksSummary: "Checks failing"),
            now: Self.now
        )

        #expect(card.state == "Checks failing")
        #expect(card.detail == nil)
    }

    @Test("A running agent keeps the pull request number under a running state")
    func runningKeepsItsPullRequest() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(additions: 12, deletions: 1, changedFiles: 1),
            isRunning: true,
            pullRequest: pullRequest(checks: .passing, checksSummary: "12 checks passed"),
            now: Self.now
        )

        #expect(card.status == .running)
        #expect(card.state == "Agent running")
        #expect(card.detail == nil)
        #expect(card.pullRequest?.number == 362)
    }

    @Test("A blocked agent outranks everything else the row could say")
    func awaitingPermission() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(additions: 4, deletions: 0, changedFiles: 1, unread: true),
            isRunning: true,
            isAwaitingPermission: true,
            now: Self.now
        )

        #expect(card.status == .awaitingPermission)
        #expect(card.state == "Waiting on you")
    }

    @Test("A title far too long for the row is carried whole")
    func longTitle() {
        let long = "Show me every place the technologies used in this project are configured, "
            + "and say which of them are pinned to a version"
        let card = WorkspaceHoverCard.make(workspace: workspace(name: long), now: Self.now)

        #expect(card.title == long)
        #expect(card.title.count == long.count)
    }

    @Test("A branch with slashes in it keeps all of them")
    func branchWithSlashes() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(branch: "agent/2026-08/fix-the-checks"), now: Self.now
        )

        #expect(card.branch == "agent/2026-08/fix-the-checks")
    }

    @Test("Six days reads as the phrase, not as the measurement")
    func sixDaysAgo() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(lastActivityAt: Self.now.addingTimeInterval(-6 * 86_400)),
            now: Self.now
        )

        #expect(card.age == "6d ago")
    }

    @Test("A workspace that has never been touched reads as just now")
    func neverTouched() {
        let card = WorkspaceHoverCard.make(workspace: workspace(), now: Self.now)

        #expect(card.age == "just now")
    }

    @Test("A timestamp from the future reads as just now rather than as a negative age")
    func futureTimestamp() {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(lastActivityAt: Self.now.addingTimeInterval(3_600)),
            now: Self.now
        )

        #expect(card.age == "just now")
    }

    static let ageRungs: [(seconds: Double, phrase: String)] = [
        (30, "just now"),
        (600, "10m ago"),
        (7_200, "2h ago"),
        (86_400 * 3, "3d ago"),
        (86_400 * 14, "2w ago"),
        (86_400 * 90, "3mo ago"),
        (86_400 * 800, "2y ago"),
    ]

    @Test("Every rung of the age scale gains the word", arguments: ageRungs)
    func agePhrases(rung: (seconds: Double, phrase: String)) {
        let card = WorkspaceHoverCard.make(
            workspace: workspace(lastActivityAt: Self.now.addingTimeInterval(-rung.seconds)),
            now: Self.now
        )

        #expect(card.age == rung.phrase)
    }

    @Test("Content between the two bounds is drawn at its own width")
    func widthFollowsTheContent() {
        #expect(HoverCardWidth.fits(content: 412) == 412)
    }

    @Test("Content narrower than the floor is drawn at the floor")
    func widthNeverGoesBelowTheFloor() {
        #expect(HoverCardWidth.fits(content: 120) == HoverCardWidth.minimum)
        #expect(HoverCardWidth.fits(content: 0) == HoverCardWidth.minimum)
    }

    @Test("Content wider than the ceiling is drawn at the ceiling")
    func widthNeverGoesAboveTheCeiling() {
        #expect(HoverCardWidth.fits(content: 900) == HoverCardWidth.ceiling)
    }

    @Test("A fractional width is rounded up to a whole point")
    func widthIsWhole() {
        #expect(HoverCardWidth.fits(content: 412.25) == 413)
    }

    @Test("A width that is not a number lands on the floor")
    func widthOfNothingAtAll() {
        #expect(HoverCardWidth.fits(content: .nan) == HoverCardWidth.minimum)
        #expect(HoverCardWidth.fits(content: .infinity) == HoverCardWidth.minimum)
    }

    @Test("The bounds are the right way round and neither is a pane")
    func boundsAreSane() {
        #expect(HoverCardWidth.minimum < HoverCardWidth.ceiling)
        #expect(HoverCardWidth.minimum > 260)
    }

    @Test("The card stands to the right of the row, its top edge on the row's")
    func placedRightOfTheRow() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let row = CGRect(x: 200, y: 800, width: 240, height: 32)

        let frame = HoverCardPlacement.frame(
            anchor: row, size: CGSize(width: 300, height: 140), visible: screen
        )

        #expect(frame.minX == row.maxX + HoverCardPlacement.gap)
        #expect(frame.maxY == row.maxY)
    }

    @Test("With no room on the right the card flips to the left of the row")
    func flipsWhenTheRightIsFull() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let row = CGRect(x: 1_100, y: 400, width: 240, height: 32)

        let frame = HoverCardPlacement.frame(
            anchor: row, size: CGSize(width: 300, height: 140), visible: screen
        )

        #expect(frame.maxX == row.minX - HoverCardPlacement.gap)
        #expect(frame.minX >= screen.minX + HoverCardPlacement.screenMargin)
    }

    @Test("With room on neither side the card is clamped rather than flipped")
    func clampedWhenNeitherSideFits() {
        let screen = CGRect(x: 0, y: 0, width: 700, height: 500)
        let row = CGRect(x: 200, y: 300, width: 240, height: 32)

        let frame = HoverCardPlacement.frame(
            anchor: row, size: CGSize(width: 300, height: 140), visible: screen
        )

        #expect(frame.maxX == screen.maxX - HoverCardPlacement.screenMargin)
        #expect(frame.minX >= screen.minX + HoverCardPlacement.screenMargin)
    }

    @Test("A row near the bottom of the screen pushes the card back up")
    func clampedAtTheBottom() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let row = CGRect(x: 200, y: 20, width: 240, height: 32)

        let frame = HoverCardPlacement.frame(
            anchor: row, size: CGSize(width: 300, height: 140), visible: screen
        )

        #expect(frame.minY == screen.minY + HoverCardPlacement.screenMargin)
        #expect(frame.maxY <= screen.maxY - HoverCardPlacement.screenMargin)
    }

    @Test("A row at the top of a screen with a non-zero origin stays on that screen")
    func clampedAtTheTopOfASecondScreen() {
        let screen = CGRect(x: -1_440, y: 200, width: 1_440, height: 900)
        let row = CGRect(x: -1_300, y: 1_064, width: 240, height: 32)

        let frame = HoverCardPlacement.frame(
            anchor: row, size: CGSize(width: 300, height: 140), visible: screen
        )

        #expect(frame.maxY <= screen.maxY - HoverCardPlacement.screenMargin)
        #expect(frame.minY >= screen.minY + HoverCardPlacement.screenMargin)
    }

    @Test("A card taller than the screen keeps its top edge on screen")
    func tallerThanTheScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 300)
        let row = CGRect(x: 200, y: 100, width: 240, height: 32)

        let frame = HoverCardPlacement.frame(
            anchor: row, size: CGSize(width: 300, height: 600), visible: screen
        )

        #expect(frame.maxY == screen.maxY - HoverCardPlacement.screenMargin)
    }

    @Test("The band's card hangs under it with their trailing edges aligned")
    func placedUnderTheBand() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let band = CGRect(x: 1_500, y: 948, width: 380, height: 52)

        let frame = HoverCardPlacement.frame(
            anchor: band, size: CGSize(width: 400, height: 160), visible: screen, side: .below
        )

        #expect(frame.maxX == band.maxX)
        #expect(frame.maxY == band.minY - HoverCardPlacement.gap)
    }

    @Test("A band against the right edge of the screen keeps the card's margin")
    func bandAgainstTheScreenEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let band = CGRect(x: 1_540, y: 1_020, width: 380, height: 52)

        let frame = HoverCardPlacement.frame(
            anchor: band, size: CGSize(width: 400, height: 160), visible: screen, side: .below
        )

        #expect(frame.maxX == screen.maxX - HoverCardPlacement.screenMargin)
        #expect(frame.minX >= screen.minX + HoverCardPlacement.screenMargin)
    }

    @Test("With no room under the band the card flips above it")
    func flipsAboveWhenThereIsNoRoomBelow() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let band = CGRect(x: 1_500, y: 100, width: 380, height: 52)

        let frame = HoverCardPlacement.frame(
            anchor: band, size: CGSize(width: 400, height: 260), visible: screen, side: .below
        )

        #expect(frame.minY == band.maxY + HoverCardPlacement.gap)
    }

    @Test("With room on neither side of the band the card is clamped rather than flipped")
    func clampedWhenNeitherAboveNorBelowFits() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 300)
        let band = CGRect(x: 1_500, y: 200, width: 380, height: 52)

        let frame = HoverCardPlacement.frame(
            anchor: band, size: CGSize(width: 400, height: 260), visible: screen, side: .below
        )

        #expect(frame.minY == screen.minY + HoverCardPlacement.screenMargin)
        #expect(frame.maxY <= screen.maxY - HoverCardPlacement.screenMargin)
    }

    @Test("A row still gets the same rectangle it did before there was a side to pass")
    func trailingIsStillTheDefault() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let row = CGRect(x: 200, y: 800, width: 240, height: 32)
        let size = CGSize(width: 300, height: 140)

        #expect(
            HoverCardPlacement.frame(anchor: row, size: size, visible: screen)
                == HoverCardPlacement.frame(
                    anchor: row, size: size, visible: screen, side: .trailing
                )
        )
    }
}
