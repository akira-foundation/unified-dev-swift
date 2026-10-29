import Testing
import Foundation
@testable import Core

@Suite("A turn that fails because the account is signed out")
struct AgentAccountSignOutTests {
    @Test func theWordsTheCliWasMeasuredPrintingAreRecognised() {
        #expect(AgentAccountSignOut.isReported(in: "Not logged in · Please run /login"))
        #expect(AgentAccountSignOut.isReported(in: "not logged in"))
    }

    @Test func otherFailuresAreNotTakenForASignOut() {
        #expect(!AgentAccountSignOut.isReported(in: ""))
        #expect(!AgentAccountSignOut.isReported(in: "API Error: 529 overloaded"))
        #expect(!AgentAccountSignOut.isReported(in: "You have logged in successfully"))
    }

    @Test func aFailureOnTheAccountJustSwitchedToIsTheCostOfTryingIt() {
        let work = AccountFixture.work.id
        #expect(AgentAccountSignOut.cause(afterSwitchingTo: work, failedOn: work) == .afterSwitch)
    }

    @Test func aFailureOnAnyOtherAccountEndedSomewhereElse() {
        let work = AccountFixture.work.id
        #expect(AgentAccountSignOut.cause(afterSwitchingTo: nil, failedOn: work) == .endedElsewhere)
        #expect(AgentAccountSignOut.cause(afterSwitchingTo: AccountFixture.personal.id, failedOn: work) == .endedElsewhere)
    }

    @Test func endingElsewhereSaysSoAndSaysNothingWasDoneByTheApp() {
        let text = AgentAccountSignOut.headline(.endedElsewhere, account: "ada@client.example", provider: .claudeCode)
        #expect(text.contains("ada@client.example was signed out somewhere else"))
        #expect(text.contains("whatever Unified Dev did"))
        #expect(!text.contains("failed"))
    }

    @Test func tryingAnAccountThatFailsSaysTheSignInMayBeGone() {
        let text = AgentAccountSignOut.headline(.afterSwitch, account: "ada@client.example", provider: .claudeCode)
        #expect(text.contains("Claude Code says ada@client.example is not signed in"))
        #expect(text.contains("removes it"))
        #expect(text.contains("may have cost it"))
    }

    @Test func recoveryDoesNotPointAtAButtonThatDoesNotExist() {
        let text = AgentAccountSignOut.recovery(provider: .codex)
        #expect(text.contains("no sign-in button"))
        #expect(text.contains("Codex config directory"))
    }
}
