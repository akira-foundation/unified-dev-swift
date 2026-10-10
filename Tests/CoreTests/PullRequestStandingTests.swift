import Foundation
import Testing
@testable import Core

@Suite("Pull request standing")
struct PullRequestStandingTests {
    private static let branch = "feat/213-pull-request-bar-path"

    private func pullRequest(
        state: String = "OPEN",
        isDraft: Bool = false,
        mergeable: String? = "MERGEABLE",
        checks: PullRequest.Checks = .none,
        checksSummary: String = ""
    ) -> PullRequest {
        PullRequest(
            number: 213,
            title: "The pull request bar announces where the work stands",
            url: "https://github.com/akira-foundation/unified-dev-swift/pull/213",
            state: state,
            isDraft: isDraft,
            mergeable: mergeable,
            checks: checks,
            checksSummary: checksSummary,
            branch: Self.branch
        )
    }

    private func standing(
        pullRequest: PullRequest?,
        ahead: Int = 3,
        aheadIsCapped: Bool = false,
        localWork: LocalWork? = nil,
        hasRemote: Bool = true
    ) -> PullRequestStanding {
        PullRequestStanding.of(
            branch: Self.branch,
            baseBranch: "main",
            ahead: ahead,
            aheadIsCapped: aheadIsCapped,
            pullRequest: pullRequest,
            localWork: localWork,
            hasRemote: hasRemote
        )
    }

    @Test("A project with no remote shows what it has and nothing it cannot do")
    func withoutRemote() {
        let standing = standing(pullRequest: nil, hasRemote: false)

        #expect(standing.path.isEmpty)
        #expect(standing.links.isEmpty)
        #expect(standing.button == nil)
        #expect(standing.current == nil)
        #expect(standing.ahead == "3 \u{2191}")
        #expect(standing.note == "No remote, so nowhere to push")
        #expect(standing.headline == Self.branch)
        #expect(standing.target == "main")
    }

    @Test("A branch with commits and no pull request stands on commits, and opening one is next")
    func withoutPullRequest() {
        let standing = standing(pullRequest: nil)

        #expect(standing.current == .commits)
        #expect(standing.path == PullRequestStep.whole)
        #expect(standing.button?.act == .openPullRequest)
        #expect(standing.button?.label == "Open PR")
        #expect(standing.state == nil)
        #expect(standing.ahead == "3 \u{2191}")
        #expect(standing.reach(of: .commits) == .diff)
        #expect(standing.reach(of: .pullRequest) == nil)
        #expect(standing.reach(of: .merge) == nil)
    }

    @Test("A branch with nothing on it is not offered a pull request")
    func nothingToOpen() {
        let standing = standing(pullRequest: nil, ahead: 0)

        #expect(standing.button == nil)
        #expect(standing.ahead == nil)
        #expect(standing.note == "Nothing has changed on this branch yet")
    }

    @Test("Uncommitted work alone is enough to offer a pull request")
    func uncommittedCounts() {
        let standing = standing(
            pullRequest: nil, ahead: 0, localWork: LocalWork(modifiedFiles: 2, hasUpstream: false)
        )

        #expect(standing.button?.act == .openPullRequest)
    }

    @Test("An open pull request with checks passing stands on merge, and merging is next")
    func readyToMerge() {
        let standing = standing(
            pullRequest: pullRequest(checks: .passing, checksSummary: "12 checks passed")
        )

        #expect(standing.current == .merge)
        #expect(standing.tone == .accent)
        #expect(standing.button?.act == .merge)
        #expect(standing.state == "Ready to merge")
        #expect(standing.number == 213)
        #expect(standing.reach(of: .merge) == .merge)
        #expect(standing.reach(of: .checks) == .checks)
    }

    @Test("Checks running light the checks step in the accent, and merging is still the next step")
    func checksRunning() {
        let standing = standing(
            pullRequest: pullRequest(checks: .pending, checksSummary: "3 checks running")
        )

        #expect(standing.current == .checks)
        #expect(standing.tone == .accent)
        #expect(standing.button?.act == .merge)
        #expect(standing.state == "Checks running")
    }

    @Test("A failed check lights the checks step in danger, and the next step writes a request")
    func checkFailed() {
        let standing = standing(
            pullRequest: pullRequest(checks: .failing, checksSummary: "1 check failed")
        )

        #expect(standing.current == .checks)
        #expect(standing.tone == .danger)
        #expect(standing.button?.act == .askToFixChecks)
        #expect(standing.button?.label == "Ask to fix")
        #expect(standing.button?.act.writesToComposer == true)
        #expect(standing.state == "Checks failing")
    }

    @Test("A conflict lights the merge step in warning, and nothing offers to merge")
    func conflicting() {
        let standing = standing(pullRequest: pullRequest(mergeable: "CONFLICTING"))

        #expect(standing.current == .merge)
        #expect(standing.tone == .warning)
        #expect(standing.button?.act == .askToFixConflicts)
        #expect(standing.button?.act.writesToComposer == true)
        #expect(standing.reach(of: .merge) == nil)
        #expect(standing.state == "Merge conflicts")
    }

    @Test("A draft stands on the pull request, and marking it ready is next")
    func draft() {
        let standing = standing(pullRequest: pullRequest(isDraft: true))

        #expect(standing.current == .pullRequest)
        #expect(standing.tone == .quiet)
        #expect(standing.button?.act == .markReadyForReview)
        #expect(standing.button?.label == "Mark ready")
    }

    @Test("Work GitHub does not have stands on commits, and pushing is next")
    func localWorkAhead() {
        let committed = standing(
            pullRequest: pullRequest(checks: .passing),
            localWork: LocalWork(unpushedCommits: 2)
        )
        let uncommitted = standing(
            pullRequest: pullRequest(checks: .passing),
            localWork: LocalWork(modifiedFiles: 1, unpushedCommits: 2)
        )

        #expect(committed.current == .commits)
        #expect(committed.tone == .accent)
        #expect(committed.button?.act == .push)
        #expect(committed.note == "2 commits to push")
        #expect(committed.ahead == nil)
        #expect(uncommitted.button?.act == .commitAndPush)
        #expect(uncommitted.button?.label == "Push")
        #expect(uncommitted.note == "1 file to commit, 2 commits to push")
    }

    @Test("Merged is one line with archiving as the action, and no path at all")
    func merged() {
        let standing = standing(pullRequest: pullRequest(state: "MERGED"))

        #expect(standing.path.isEmpty)
        #expect(standing.links.isEmpty)
        #expect(standing.current == nil)
        #expect(standing.state == "Merged")
        #expect(standing.tone == .merged)
        #expect(standing.button?.act == .archive)
        #expect(standing.ahead == nil)
    }

    @Test("A closed pull request keeps the path and offers nothing the app cannot do")
    func closed() {
        let standing = standing(pullRequest: pullRequest(state: "CLOSED"))

        #expect(standing.path == PullRequestStep.whole)
        #expect(standing.current == .pullRequest)
        #expect(standing.state == "Closed")
        #expect(standing.tone == .quiet)
        #expect(standing.button == nil)
        #expect(standing.reach(of: .merge) == nil)
    }

    @Test("Checks the app has not been told about are not a step to reach")
    func noChecksToOpen() {
        let standing = standing(pullRequest: pullRequest(checks: .none))

        #expect(standing.reach(of: .checks) == nil)
        #expect(standing.current == .merge)
    }

    @Test("Every step that leads somewhere says where")
    func everyLinkAnnounces() {
        let states: [PullRequest?] = [
            nil,
            pullRequest(checks: .passing),
            pullRequest(checks: .failing),
            pullRequest(mergeable: "CONFLICTING"),
            pullRequest(isDraft: true),
            pullRequest(state: "CLOSED"),
            pullRequest(state: "MERGED"),
        ]

        for state in states {
            let standing = standing(pullRequest: state)
            for link in standing.links {
                #expect(!link.announcement.isEmpty)
                #expect(standing.path.contains(link.step))
                #expect(standing.announcement(of: link.step) == link.announcement)
            }
        }
    }

    @Test("The path names its steps only where the column is wide enough")
    func labelsFollowWidth() {
        #expect(!PullRequestStanding.showsLabels(atWidth: 280))
        #expect(!PullRequestStanding.showsLabels(atWidth: 380))
        #expect(!PullRequestStanding.showsLabels(atWidth: PullRequestStanding.labelledWidth - 1))
        #expect(PullRequestStanding.showsLabels(atWidth: PullRequestStanding.labelledWidth))
        #expect(PullRequestStanding.showsLabels(atWidth: 760))
    }

    @Test("Every button is short enough to sit in the narrow column, and says more on hover")
    func buttonsAreShort() {
        for act in PullRequestStanding.Act.allCases {
            #expect(act.label.count <= 11)
            #expect(!act.label.isEmpty)
        }

        let failing = standing(pullRequest: pullRequest(checks: .failing))
        #expect(failing.button?.sentence.count ?? 0 > failing.button?.label.count ?? 0)
    }

    @Test("A count past the limit says it is a floor rather than the number")
    func cappedCount() {
        let standing = standing(pullRequest: nil, ahead: 50, aheadIsCapped: true)

        #expect(standing.ahead == "50+ \u{2191}")
        #expect(standing.aheadAnnouncement == "more than 50 commits ahead of main")
    }

    @Test("One commit is a commit")
    func oneCommit() {
        let standing = standing(pullRequest: nil, ahead: 1)

        #expect(standing.ahead == "1 \u{2191}")
        #expect(standing.aheadAnnouncement == "1 commit ahead of main")
    }

    @Test("Only the two asking buttons write into the composer")
    func onlyAskingWrites() {
        let writing = PullRequestStanding.Act.allCases.filter(\.writesToComposer)

        #expect(Set(writing) == [.askToFixChecks, .askToFixConflicts])
    }
}
