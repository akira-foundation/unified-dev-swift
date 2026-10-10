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
        #expect(text.contains("Find out why and fix it in this worktree."))
        #expect(text.contains("#213 is not merged"))
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

    @Test("The request ends with the ask, so the last thing read is what to do")
    func asksLast() {
        let text = CheckFailureHandoff.request([lint, build], moreFailed: 2, number: 213)

        #expect(text.hasSuffix("is not merged until you say so."))
    }
}
