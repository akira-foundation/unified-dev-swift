import Foundation
import Testing
@testable import Core

@Suite("Check failure request")
struct CheckFailureRequestTests {
    private let lint = CheckFailureHandoff.Mention(
        name: "lint",
        workflow: "test",
        detailsURL: "https://github.com/akira-foundation/unified-dev-swift/actions/runs/42",
        logPath: ".unifieddev/attachments/aB3xZ9/lint.log",
        excerpt: CheckFailureHandoff.Excerpt(text: "error", totalLines: 1, droppedLines: 0)
    )

    private let build = CheckFailureHandoff.Mention(name: "build", workflow: "test")

    @Test("The request names the check, carries its log and asks for a fix")
    func oneFailure() {
        let text = CheckFailureHandoff.request([lint], number: 213)

        #expect(text.contains("The GitHub check \"lint\" in test failed."))
        #expect(text.contains(AttachmentDraft.token(for: lint.logPath!)))
        #expect(text.contains("Find out why, fix it in this worktree"))
        #expect(text.contains("Do not merge #213."))
    }

    @Test("A check whose log could not be read says so rather than pretending")
    func withoutALog() {
        let text = CheckFailureHandoff.request([build], number: 213)

        #expect(text.contains("Unified Dev could not fetch its log."))
    }

    @Test("Every carried check is described")
    func severalFailures() {
        let text = CheckFailureHandoff.request([lint, build], number: 213)

        #expect(text.contains("\"lint\""))
        #expect(text.contains("\"build\""))
    }

    @Test("Checks left out of the request are counted rather than hidden")
    func moreFailed() {
        let one = CheckFailureHandoff.request([lint], moreFailed: 1, number: 213)
        let four = CheckFailureHandoff.request([lint], moreFailed: 4, number: 213)

        #expect(one.contains("1 other check on #213 failed too, and its log is not here."))
        #expect(four.contains("4 other checks on #213 failed too, and their logs are not here."))
        #expect(!CheckFailureHandoff.request([lint], number: 213).contains("failed too"))
    }

    @Test("A log goes to the check it came from, by order of the checks that produced one")
    func carriesLogsToTheirChecks() {
        let third = CheckFailureHandoff.Mention(
            name: "test",
            excerpt: CheckFailureHandoff.Excerpt(text: "boom", totalLines: 1, droppedLines: 0)
        )
        let carried = CheckFailureHandoff.carrying(
            [lint, build, third], logPaths: ["lint.log", "test.log"]
        )

        #expect(carried.map(\.logPath) == ["lint.log", nil, "test.log"])
    }

    @Test("A log that was not written leaves every check without one, rather than the wrong one")
    func refusesToGuess() {
        let third = CheckFailureHandoff.Mention(
            name: "test",
            excerpt: CheckFailureHandoff.Excerpt(text: "boom", totalLines: 1, droppedLines: 0)
        )
        let carried = CheckFailureHandoff.carrying([lint, build, third], logPaths: ["test.log"])

        #expect(carried.allSatisfy { $0.logPath == nil })
        #expect(carried.allSatisfy { $0.excerpt == nil })
        #expect(CheckFailureHandoff.request(carried, number: 213)
            .contains("Unified Dev could not fetch its log."))
    }

    @Test("The request ends with the ask, so the last thing read is what to do")
    func asksLast() {
        let text = CheckFailureHandoff.request([lint, build], moreFailed: 2, number: 213)

        #expect(text.hasSuffix("Do not merge #213."))
    }

    @Test("The fix is pushed to the pull request's branch and nowhere else")
    func pushesTheFix() {
        let text = CheckFailureHandoff.request([lint], number: 213)

        #expect(text.contains("commit the fix and push it to the branch of #213 and no other"))
        #expect(text.contains("then wait for its checks, thirty minutes at most"))
        #expect(text.contains("Never force the push"))
    }

    @Test("A moved branch, a fork or auto-merge stops the push")
    func refusesToPush() {
        let text = CheckFailureHandoff.request([lint], number: 213)

        #expect(text.contains(
            "Fetch first: if the branch on the server has commits this worktree lacks, or #213 comes"
                + " from a fork, or auto-merge is on for it, push nothing and say so."
        ))
    }

    @Test("Doubt or unpublished work leaves the fix unpushed")
    func doubtLeavesItUnpushed() {
        let text = CheckFailureHandoff.request([lint], number: 213)

        #expect(text.contains("If you are not sure of the fix, or this worktree held other work GitHub has not got, leave it unpushed and say why."))
    }

    @Test("The check is never turned green by weakening it")
    func checksAreNotWeakened() {
        let text = CheckFailureHandoff.request([lint], number: 213)

        #expect(text.contains("never edit a workflow, skip or loosen a test or relax a lint rule to turn the check green"))
    }
}
