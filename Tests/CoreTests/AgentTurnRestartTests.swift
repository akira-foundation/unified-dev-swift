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
        lastSent: String? = "later message",
        recordedAccountIsPresent: Bool = true,
        turnPromptIsAppRequest: Bool = false,
        lastSentIsAppRequest: Bool = false
    ) -> Result<AgentTurnRestart, AgentTurnRestart.Refused> {
        AgentTurnRestart.decide(AgentTurnRestart.Input(
            isWorkspaceArchiving: archiving,
            session: session ?? self.session,
            resolution: resolution ?? .resolved(defaultClaude),
            target: target ?? work,
            isTurnInFlight: running,
            turnPrompt: turnPrompt.map { .init(text: $0, isAppRequest: turnPromptIsAppRequest) },
            lastSentTurn: lastSent.map { .init(text: $0, isAppRequest: lastSentIsAppRequest) },
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

    @Test func aHiddenTurnRestartsHiddenAndAnOwnersTurnDoesNot() {
        #expect(restart(decide(turnPromptIsAppRequest: true))?.isAppRequest == true)
        #expect(restart(decide(turnPromptIsAppRequest: true))?.prompt == "build the invoice page")
        #expect(restart(decide())?.isAppRequest == false)
        #expect(restart(decide(lastSentIsAppRequest: true))?.isAppRequest == false)
    }

    @Test func afterAReloadTheLastTurnKeepsItsOwnMark() {
        let hidden = restart(decide(turnPrompt: nil, lastSentIsAppRequest: true))
        #expect(hidden?.isAppRequest == true)
        #expect(hidden?.prompt == "later message")
        #expect(restart(decide(turnPrompt: nil))?.isAppRequest == false)
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
        #expect(restart(decide(turnPrompt: "the one that stopped", lastSent: "the last one"))?.prompt == "the one that stopped")
    }

    @Test func theLastMessageInTheChatIsUsedWhenTheTurnPromptIsUnknownOrBlank() {
        #expect(restart(decide(turnPrompt: nil, lastSent: "the last one"))?.prompt == "the last one")
        #expect(restart(decide(turnPrompt: "  \n", lastSent: "the last one"))?.prompt == "the last one")
    }

    @Test func withNoMessageAtAllThereIsNothingToRestart() {
        #expect(sentence(decide(turnPrompt: nil, lastSent: nil)) == "This chat has no message to start again.")
        #expect(sentence(decide(turnPrompt: " ", lastSent: "")) == "This chat has no message to start again.")
    }

    @Test func anArchivingWorkspaceRefusesFirstOfAll() {
        let result = decide(archiving: true, resolution: .failed("boom"), turnPrompt: nil, lastSent: nil)
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

    private func resolution(_ homes: [(AgentAccountHome, Bool)]) -> AgentAccountResolution {
        AgentAccountResolution(
            standings: homes.map { AccountFixture.standing($0.0, exists: $0.1) },
            choices: [:]
        )
    }

    @Test func whetherTheRecordedAccountIsHereIsReadFromTheStandingsOfTheResolution() {
        var named = session
        named.accountID = AccountFixture.personal.id
        let here = resolution([(work, true), (AccountFixture.personal, true)])
        let gone = resolution([(work, true), (AccountFixture.personal, false)])
        let unknown = resolution([(work, true)])

        #expect(AgentTurnRestart.isRecordedAccountPresent(of: named, in: here))
        #expect(!AgentTurnRestart.isRecordedAccountPresent(of: named, in: gone))
        #expect(!AgentTurnRestart.isRecordedAccountPresent(of: named, in: unknown))
    }

    @Test func aChatThatNamesNoAccountOrAResolutionThatFailedCountsAsHere() {
        let gone = resolution([(AccountFixture.personal, false)])
        var named = session
        named.accountID = AccountFixture.personal.id

        #expect(AgentTurnRestart.isRecordedAccountPresent(of: session, in: gone))
        #expect(AgentTurnRestart.isRecordedAccountPresent(of: named, in: nil))
    }

    @Test func aDefaultAccountCountsAsHereEvenWithoutItsFolder() {
        var named = session
        named.accountID = defaultClaude.id
        let gone = resolution([(defaultClaude, false)])

        #expect(AgentTurnRestart.isRecordedAccountPresent(of: named, in: gone))
    }

    @Test func aChatWhoseHistoryBelongsToAnAccountThatIsHereIsMovedAndSaysTheHistoryStaysThere() {
        var elsewhere = session
        elsewhere.accountID = AccountFixture.personal.id
        let made = restart(decide(session: elsewhere))
        #expect(made?.steps == [.chooseAccount, .retireRunner, .submit])
        #expect(made?.destination.id == work.id)
        #expect(made?.notice == AgentTurnRestart.historyStaysNotice(for: .claudeCode))
    }

    @Test func movingAChatOntoTheAccountThatHoldsItsHistoryIsRecoveryAndSaysNothing() {
        var elsewhere = session
        elsewhere.accountID = AccountFixture.personal.id
        let made = restart(decide(session: elsewhere, target: AccountFixture.personal))
        #expect(made?.destination.id == AccountFixture.personal.id)
        #expect(made?.notice == nil)
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
        let said = sentence(decide(target: AccountFixture.defaultCodex, turnPrompt: nil, lastSent: nil))
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

    @Test func aChatWhoseHistoryBelongsElsewhereStillMeetsTheProviderAndSameAccountRefusals() {
        var elsewhere = session
        elsewhere.accountID = AccountFixture.personal.id
        #expect(sentence(decide(session: elsewhere, target: AccountFixture.defaultCodex))
            == "Codex accounts cannot run a Claude Code chat.")
        #expect(sentence(decide(session: elsewhere, target: defaultClaude)) == "This chat already runs on that account.")
    }

    @Test func theSameAccountGuardComesBeforeTheMissingPromptGuard() {
        let said = sentence(decide(target: defaultClaude, turnPrompt: nil, lastSent: nil))
        #expect(said == "This chat already runs on that account.")
    }

    @Test func theProviderRefusalComesBeforeTheMissingPromptGuard() {
        let said = sentence(decide(target: AccountFixture.defaultCodex, turnPrompt: nil, lastSent: nil))
        #expect(said == "Codex accounts cannot run a Claude Code chat.")
    }

    @Test func theTwoFailuresOfTheExecutionAreSaidInPlainWords() {
        #expect(AgentTurnRestart.turnDidNotStop == "The running turn did not stop in time, so the account was not changed.")
        #expect(AgentTurnRestart.notRestarted == "Unified Dev could not start the message again.")
    }
}
