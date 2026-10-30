import Testing
import Foundation
@testable import Core

@Suite("A turn that fails because the account is signed out")
struct AgentAccountSignOutTests {
    private func result(
        _ summary: String,
        isError: Bool = true,
        subtype: String = "success",
        terminalReason: String? = "api_error"
    ) -> AgentResult {
        AgentResult(summary: summary, isError: isError, subtype: subtype, numTurns: 1, terminalReason: terminalReason)
    }

    private func observe(_ result: AgentResult, replaying: Bool = false, reconciling: Bool = false) -> AgentAccountSignOut.Observation {
        AgentAccountSignOut.observe(result, isReplayingPastTurn: replaying, isReconcilingPresentation: reconciling)
    }

    @Test func theResultTheCliWasMeasuredWritingIsASignOut() {
        #expect(observe(result("Not logged in · Please run /login")) == .signedOut)
    }

    @Test func theWordsAreMatchedAtTheStartAndIgnoringCase() {
        #expect(observe(result("  not logged in")) == .signedOut)
    }

    @Test func theAgentWritingTheSameWordsInAFailedTurnIsNotASignOut() {
        let prose = "The login flow works, but the user is not logged in until the cookie is set."
        #expect(observe(result(prose)) == .none)
        #expect(observe(result("I am not logged in here, so I could not finish", terminalReason: nil)) == .none)
        #expect(observe(result("Not logged in", terminalReason: "max_tokens")) == .none)
    }

    @Test func aFailureForAnotherReasonIsNeitherASignOutNorProofThatTheAccountWorks() {
        #expect(observe(result("API Error: 529 overloaded")) == .none)
    }

    @Test func aSuccessfulTurnProvesTheAccountWorks() {
        #expect(observe(result("Done", isError: false, terminalReason: nil)) == .working)
    }

    @Test func aReplayedOrReconciledTurnProvesNothing() {
        let signedOut = result("Not logged in · Please run /login")
        let fine = result("Done", isError: false, terminalReason: nil)
        #expect(observe(signedOut, replaying: true) == .none)
        #expect(observe(signedOut, reconciling: true) == .none)
        #expect(observe(fine, replaying: true) == .none)
        #expect(observe(fine, reconciling: true) == .none)
    }

    @Test func notSignedInSaysItMayHaveExpiredAndDoesNotClaimWhoEndedIt() {
        let text = AgentAccountSignOut.headline(.notSignedIn, account: "ada@client.example", provider: .claudeCode)
        #expect(text.contains("Claude Code says ada@client.example is not signed in"))
        #expect(text.contains("signed out somewhere else or its sign-in may have expired"))
        #expect(text.contains("whatever Unified Dev did"))
        #expect(!text.contains("was signed out"))
    }

    @Test func tryingAnAccountThatFailsSaysTheSignInMayBeGone() {
        let text = AgentAccountSignOut.headline(.afterSwitch, account: "ada@client.example", provider: .claudeCode)
        #expect(text.contains("Claude Code says ada@client.example is not signed in"))
        #expect(text.contains("removes it"))
        #expect(text.contains("may have cost it"))
    }

    @Test func recoveryDoesNotPointAtAButtonThatDoesNotExistNorAtAnotherAccount() {
        let text = AgentAccountSignOut.recovery(provider: .codex)
        #expect(text.contains("no sign-in button"))
        #expect(text.contains("Codex config directory"))
        #expect(!text.contains("another account"))
    }
}
