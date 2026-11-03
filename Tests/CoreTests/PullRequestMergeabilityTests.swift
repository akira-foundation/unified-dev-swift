import Foundation
import Testing
@testable import Core

@Suite("A pull request GitHub has not finished checking")
struct PullRequestMergeabilityTests {
    private func pullRequest(
        mergeable: String?,
        checks: PullRequest.Checks = .passing,
        isDraft: Bool = false
    ) -> PullRequest {
        PullRequest(
            number: 42,
            title: "Add the glyph",
            url: "https://github.com/acme/widgets/pull/42",
            state: "OPEN",
            isDraft: isDraft,
            mergeable: mergeable,
            checks: checks,
            checksSummary: "",
            reviewDecision: nil,
            branch: "feature/glyphs"
        )
    }

    @Test("UNKNOWN is neither ready nor mergeable", arguments: ["UNKNOWN", "unknown"])
    func unknownIsNotReady(mergeable: String) {
        let status = pullRequest(mergeable: mergeable).status

        #expect(!status.canMerge)
        #expect(status.text == "Checking for conflicts")
        #expect(status.blockedReason != nil)
    }

    @Test("an answer from GitHub still reads as ready", arguments: ["MERGEABLE", "CLEAN"])
    func answerIsReady(mergeable: String) {
        let status = pullRequest(mergeable: mergeable).status

        #expect(status.canMerge)
        #expect(status.text == "Ready to merge")
    }

    @Test("no answer at all does not hold the merge back")
    func missingFieldStaysMergeable() {
        #expect(pullRequest(mergeable: nil).status.canMerge)
    }

    @Test("a conflict and a draft keep their own state", arguments: [
        ("CONFLICTING", false, "Merge conflicts"),
        ("UNKNOWN", true, "Draft"),
    ])
    func otherStatesWin(mergeable: String, isDraft: Bool, text: String) {
        #expect(pullRequest(mergeable: mergeable, isDraft: isDraft).status.text == text)
    }

    @Test("unpushed work still offers the push, and the merge stays refused")
    func localWorkStaysRefused() {
        let status = pullRequest(mergeable: "UNKNOWN")
            .status(local: LocalWork(modifiedFiles: 0, unpushedCommits: 1))

        #expect(status.remedy == .push)
        #expect(!status.canMerge)
        #expect(status.text == "Checking for conflicts")
    }

    @Test("the bar says it is checking and offers no way to the merge", arguments: [
        PullRequest.Checks.passing, .none,
    ])
    func standingSaysItIsChecking(checks: PullRequest.Checks) {
        let standing = PullRequestStanding.of(
            branch: "feature/glyphs",
            baseBranch: "main",
            pullRequest: pullRequest(mergeable: "UNKNOWN", checks: checks)
        )

        #expect(standing.state == "Checking for conflicts")
        #expect(standing.secondary.contains("checking for conflicts"))
        #expect(!standing.secondary.contains("ready to merge"))
        #expect(!standing.links.contains { $0.reach == .merge })
        #expect(standing.button?.sentence == pullRequest(mergeable: "UNKNOWN", checks: checks).status.blockedReason)
    }

    @Test("only the merge button speaks for the wait")
    func otherButtonsKeepTheirOwnSentence() {
        let failing = pullRequest(mergeable: "UNKNOWN", checks: .failing)
        let standing = PullRequestStanding.of(
            branch: "feature/glyphs", baseBranch: "main", pullRequest: failing
        )

        #expect(standing.button?.act == .askToFixChecks)
        #expect(standing.button?.sentence != failing.status.blockedReason)
    }

    @Test("a check that failed or is running still says so, and the merge stays refused", arguments: [
        (PullRequest.Checks.failing, "Checks failing"),
        (.pending, "Checks running"),
        (.unavailable, GitHub.checksUnavailableSummary),
    ])
    func checksKeepTheirHeadline(checks: PullRequest.Checks, text: String) {
        let status = pullRequest(mergeable: "UNKNOWN", checks: checks).status

        #expect(status.text == text)
        #expect(!status.canMerge)
        #expect(status.blockedReason != nil)
    }
}
