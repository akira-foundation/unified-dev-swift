import Foundation
import Testing
@testable import Core

@Suite("Whether a merge can be confirmed")
struct MergeConfirmationTests {
    private static let blocked = BranchActionAvailability(isAllowed: false)

    private static func pullRequest(state: String = "OPEN", isDraft: Bool = false) -> PullRequest {
        PullRequest(
            number: 7, title: "Work", url: "https://example/7", state: state, isDraft: isDraft,
            mergeable: "MERGEABLE", checks: .passing, branch: "feat/work", baseBranch: "main"
        )
    }

    private static func canConfirm(
        _ pullRequest: PullRequest?,
        branchActions: BranchActionAvailability = .allowed,
        isWorking: Bool = false
    ) -> Bool {
        MergeConfirmation.canConfirm(
            pullRequest: pullRequest, localWork: nil, branchActions: branchActions, isWorking: isWorking
        )
    }

    @Test("an open pull request ready to merge can be confirmed")
    func readyPullRequest() {
        #expect(Self.canConfirm(Self.pullRequest()))
    }

    @Test("no pull request cannot be confirmed")
    func noPullRequest() {
        #expect(!Self.canConfirm(nil))
    }

    @Test("a pull request that is no longer open cannot be confirmed", arguments: ["MERGED", "CLOSED", "UNKNOWN"])
    func notOpen(state: String) {
        #expect(!Self.canConfirm(Self.pullRequest(state: state)))
    }

    @Test("a draft cannot be confirmed")
    func draft() {
        #expect(!Self.canConfirm(Self.pullRequest(isDraft: true)))
    }

    @Test("a branch the app may not act on cannot be confirmed")
    func branchActionsRefused() {
        #expect(!Self.canConfirm(Self.pullRequest(), branchActions: Self.blocked))
    }

    @Test("nothing can be confirmed while a request is on its way")
    func working() {
        #expect(!Self.canConfirm(Self.pullRequest(), isWorking: true))
    }
}
