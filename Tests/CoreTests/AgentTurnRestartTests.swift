import Testing
import Foundation
@testable import Core

@Suite("Restarting a turn on another account")
struct AgentTurnRestartTests {
    private let defaultClaude = AccountFixture.defaultClaude
    private let work = AccountFixture.work
    private let session = Session(workspaceID: nil, agentSessionID: "agent-session-1")

    private func decide(
        session: Session? = nil,
        archiving: Bool = false,
        resolution: AgentTurnRestart.Resolution? = nil,
        target: AgentAccountHome? = nil,
        running: Bool = false,
        turnPrompt: String? = "build the invoice page",
        lastUserText: String? = "later message",
        recordedAccountIsPresent: Bool = true
    ) -> Result<AgentTurnRestart, AgentTurnRestart.Refused> {
        AgentTurnRestart.decide(AgentTurnRestart.Input(
            isWorkspaceArchiving: archiving,
            session: session ?? self.session,
            resolution: resolution ?? .resolved(defaultClaude),
            target: target ?? work,
            isTurnInFlight: running,
            turnPrompt: turnPrompt,
            lastUserText: lastUserText,
            isRecordedAccountPresent: recordedAccountIsPresent
        ))
    }

    private func sentence(_ result: Result<AgentTurnRestart, AgentTurnRestart.Refused>) -> String? {
        guard case .failure(let refused) = result else { return nil }
        return refused.sentence
    }

    private func restart(_ result: Result<AgentTurnRestart, AgentTurnRestart.Refused>) -> AgentTurnRestart? {
        guard case .success(let restart) = result else { return nil }
        return restart
    }

    @Test func aTurnThatEndedIsRestartedWithoutStoppingAnything() {
        let made = restart(decide())
        #expect(made?.steps == [.chooseAccount, .retireRunner, .submit])
        #expect(made?.destination.id == work.id)
        #expect(made?.destination.directory == work.directory)
    }

    @Test func aTurnInFlightIsStoppedAndWaitedForBeforeAnythingIsChanged() {
        #expect(restart(decide(running: true))?.steps == [
            .stopTurn, .waitForTurnToSettle, .chooseAccount, .retireRunner, .submit,
        ])
    }

    @Test func theMessageOfTheTurnThatStoppedWinsOverTheLastMessageInTheChat() {
        #expect(restart(decide(turnPrompt: "the one that stopped", lastUserText: "the last one"))?.prompt == "the one that stopped")
    }

    @Test func theLastMessageInTheChatIsUsedWhenTheTurnPromptIsUnknownOrBlank() {
        #expect(restart(decide(turnPrompt: nil, lastUserText: "the last one"))?.prompt == "the last one")
        #expect(restart(decide(turnPrompt: "  \n", lastUserText: "the last one"))?.prompt == "the last one")
    }

    @Test func withNoMessageAtAllThereIsNothingToRestart() {
        #expect(sentence(decide(turnPrompt: nil, lastUserText: nil)) == "This chat has no message to start again.")
        #expect(sentence(decide(turnPrompt: " ", lastUserText: "")) == "This chat has no message to start again.")
    }

    @Test func anArchivingWorkspaceRefusesFirstOfAll() {
        let result = decide(archiving: true, resolution: .failed("boom"), turnPrompt: nil, lastUserText: nil)
        #expect(sentence(result) == AgentTurnRestart.workspaceArchiving)
        #expect(AgentTurnRestart.workspaceArchiving == "The workspace is being archived.")
    }

    @Test func aFailedResolutionIsSaidWithItsReason() {
        #expect(sentence(decide(resolution: .failed("database is locked")))
            == "Unified Dev could not work out which account this chat runs under: database is locked")
    }

    @Test func anAgentWithNoAccountsIsRefusedByName() {
        #expect(sentence(decide(resolution: .resolved(nil))) == "Claude Code has no separate accounts.")
    }

    @Test func aChatWhoseHistoryBelongsToAnAccountThatIsHereIsNotMoved() {
        var elsewhere = session
        elsewhere.accountID = AccountFixture.personal.id
        let said = sentence(decide(session: elsewhere))
        #expect(said?.contains("history belongs to a different account") == true)
    }

    @Test func aChatWhoseAccountIsNotOnThisMacIsMovedAndSaysWhatThatCosts() {
        var stranded = session
        stranded.accountID = AccountFixture.personal.id
        let made = restart(decide(session: stranded, recordedAccountIsPresent: false))
        #expect(made?.steps == [.chooseAccount, .retireRunner, .submit])
        #expect(made?.destination.id == work.id)
        #expect(made?.notice == AgentTurnRestart.strandedNotice(for: .claudeCode))
    }

    @Test func aChatThatNamesTheAccountItRunsUnderIsMoved() {
        var named = session
        named.accountID = defaultClaude.id
        #expect(restart(decide(session: named)) != nil)
        #expect(restart(decide(session: named))?.notice == nil)
    }

    @Test func aChatThatNamesNoAccountIsMovedWithoutANotice() {
        #expect(restart(decide())?.notice == nil)
    }

    @Test func anAccountOfAnotherAgentIsRefusedBeforeAnythingElseAboutTheTarget() {
        let said = sentence(decide(target: AccountFixture.defaultCodex, turnPrompt: nil, lastUserText: nil))
        #expect(said == "Codex accounts cannot run a Claude Code chat.")
    }

    @Test func choosingTheAccountTheChatAlreadyRunsOnSaysSoInsteadOfDoingNothing() {
        #expect(sentence(decide(target: defaultClaude)) == "This chat already runs on that account.")
    }

    @Test func theSameAccountIsRefusedEvenIfTheLabelWasEdited() {
        let renamed = AgentAccountHome(
            provider: .claudeCode, id: defaultClaude.id, directory: defaultClaude.directory, isDefault: true, label: "Edited"
        )
        #expect(sentence(decide(target: renamed)) == "This chat already runs on that account.")
    }

    @Test func theOwnerGuardComesBeforeTheProviderRefusalAndTheSameAccountGuard() {
        var elsewhere = session
        elsewhere.accountID = AccountFixture.personal.id
        let againstOtherProvider = decide(session: elsewhere, target: AccountFixture.defaultCodex)
        #expect(sentence(againstOtherProvider)?.contains("history belongs") == true)
        let againstSameAccount = decide(session: elsewhere, target: defaultClaude)
        #expect(sentence(againstSameAccount)?.contains("history belongs") == true)
    }

    @Test func theSameAccountGuardComesBeforeTheMissingPromptGuard() {
        let said = sentence(decide(target: defaultClaude, turnPrompt: nil, lastUserText: nil))
        #expect(said == "This chat already runs on that account.")
    }

    @Test func theProviderRefusalComesBeforeTheMissingPromptGuard() {
        let said = sentence(decide(target: AccountFixture.defaultCodex, turnPrompt: nil, lastUserText: nil))
        #expect(said == "Codex accounts cannot run a Claude Code chat.")
    }

    @Test func theTwoFailuresOfTheExecutionAreSaidInPlainWords() {
        #expect(AgentTurnRestart.turnDidNotStop == "The running turn did not stop in time, so the account was not changed.")
        #expect(AgentTurnRestart.notRestarted == "Unified Dev could not start the message again.")
    }
}
