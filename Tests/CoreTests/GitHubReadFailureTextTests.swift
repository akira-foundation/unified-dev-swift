import Testing
import Foundation
@testable import Core

/// What a failed `gh` call is drawn as: one sentence, and the command's own transcript folded
/// away behind it. The case these are written from is `gh pr view` exiting 1 and printing eleven
/// lines of usage text into a two hundred point column.
@Suite("GitHub read failure text")
struct GitHubReadFailureTextTests {
    @Test("A single sentence is the summary, and there is nothing to fold")
    func singleSentence() {
        let failure = GitHubReadFailure(reason: .unavailable, message: "Connect GitHub again.")

        #expect(failure.summary == "Connect GitHub again.")
        #expect(failure.transcript == nil)
    }

    @Test("The first line leads and the rest is the transcript")
    func transcriptFollows() {
        let failure = GitHubReadFailure(
            reason: .unavailable,
            message: """
            `gh pr view` exited 1: argument required when using the --repo flag

            Usage:  gh pr view [<number> | <url> | <branch>] [flags]

            Flags:
              -c, --comments   View pull request comments
            """
        )

        #expect(failure.summary == "`gh pr view` exited 1: argument required when using the --repo flag")
        #expect(failure.transcript?.contains("Usage:") == true)
        #expect(failure.transcript?.contains("--comments") == true)
        #expect(failure.transcript?.hasPrefix("`gh pr view`") == false)
    }

    @Test("Leading and trailing blank lines are not the summary")
    func trimsAround() {
        let failure = GitHubReadFailure(reason: .rateLimited, message: "\n\nRate limited.\n\n")

        #expect(failure.summary == "Rate limited.")
        #expect(failure.transcript == nil)
    }
}
