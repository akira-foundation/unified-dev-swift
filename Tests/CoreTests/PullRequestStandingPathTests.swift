import Foundation
import Testing
@testable import Core

@Suite("The pull request path")
struct PullRequestStandingPathTests {
    private static let branch = "feat/213-pull-request-bar-path"

    private func pullRequest(
        state: String = "OPEN",
        isDraft: Bool = false,
        mergeable: String? = "MERGEABLE",
        checks: PullRequest.Checks = .none,
        checksSummary: String = "",
        reviewDecision: String? = nil
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
            reviewDecision: reviewDecision,
            branch: Self.branch
        )
    }

    private func standing(
        pullRequest: PullRequest?,
        ahead: Int = 3,
        aheadIsCapped: Bool = false,
        hasUnreadCommitCount: Bool = false,
        localWork: LocalWork? = nil,
        hasRemote: Bool = true,
        continued: ContinuedBranch? = nil
    ) -> PullRequestStanding {
        PullRequestStanding.of(
            branch: Self.branch,
            baseBranch: "main",
            ahead: ahead,
            aheadIsCapped: aheadIsCapped,
            hasUnreadCommitCount: hasUnreadCommitCount,
            pullRequest: pullRequest,
            localWork: localWork,
            hasRemote: hasRemote,
            continued: continued
        )
    }

    @Test("The path runs from commits to merge, in that order")
    func pathOrder() {
        #expect(PullRequestStep.whole == [.commits, .pullRequest, .checks, .merge])
        #expect(PullRequestStep.whole.map(\.label) == ["commits", "pull request", "checks", "merge"])
    }

    @Test("The steps behind the one the work is on are the ones it has passed")
    func reachedSteps() {
        let atChecks = standing(pullRequest: pullRequest(checks: .pending))
        let atCommits = standing(pullRequest: nil)
        let merged = standing(pullRequest: pullRequest(state: "MERGED"))

        #expect(atChecks.isReached(.commits))
        #expect(atChecks.isReached(.pullRequest))
        #expect(!atChecks.isReached(.checks))
        #expect(!atChecks.isReached(.merge))
        #expect(!atCommits.isReached(.commits))
        #expect(!merged.isReached(.commits))
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
        #expect(!PullRequestStanding.showsLabels(atWidth: PullRequestStanding.labelledWidth - 1))
        #expect(PullRequestStanding.showsLabels(atWidth: PullRequestStanding.labelledWidth))
        #expect(PullRequestStanding.showsLabels(atWidth: 380))
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

    @Test("Every state says something in its own words under the headline")
    func everyStateSpeaks() {
        let states: [PullRequest?] = [
            nil,
            pullRequest(checks: .passing),
            pullRequest(checks: .pending),
            pullRequest(checks: .failing),
            pullRequest(checks: .unavailable),
            pullRequest(mergeable: "CONFLICTING"),
            pullRequest(isDraft: true),
            pullRequest(state: "CLOSED"),
            pullRequest(state: "MERGED"),
        ]

        for state in states {
            #expect(!standing(pullRequest: state).secondary.isEmpty)
        }
        #expect(!standing(pullRequest: nil, hasRemote: false).secondary.isEmpty)
    }

}
