import Testing
import Foundation
@testable import Core

@Suite("Settling which account an agent conversation belongs to")
struct AgentSessionSettlementTests {
    private let defaultClaude = AccountFixture.defaultClaude
    private let work = AccountFixture.work
    private let personal = AccountFixture.personal

    private func session(
        agentSessionID: String? = "agent-session-1",
        kind: AgentKind = .claudeCode,
        owner: AgentAccountID? = nil
    ) -> Session {
        var made = Session(workspaceID: nil, agentSessionID: agentSessionID, agentKind: kind)
        made.accountID = owner
        return made
    }

    private func decide(
        _ session: Session,
        on account: AgentAccountHome?,
        purpose: AgentSessionSettlement.Purpose = .sending,
        deliberate: Bool = false
    ) -> AgentSessionSettlement {
        AgentSessionSettlement.decide(
            session: session, account: account, purpose: purpose, isDeliberateSwitch: deliberate
        )
    }

    @Test func aConversationWithHistoryAndNoRecordedOwnerIsLeftAloneWhateverAccountRunsIt() {
        let unknown = session(owner: nil)
        #expect(decide(unknown, on: work).changesNothing)
        #expect(decide(unknown, on: defaultClaude).changesNothing)
    }

    @Test func resolvedAccountChangeBecomesASegment() {
        let made = session(owner: work.id)
        let settled = decide(made, on: personal)
        #expect(settled.switchTarget == SessionSegmentTarget(
            agentKind: .claudeCode, accountID: personal.id, model: made.model, effort: made.effort
        ))
        #expect(settled.recordedAccount == nil)
    }

    @Test func aChangeOfAccountIsASegmentWithOrWithoutANativeSession() {
        for stored in ["agent-session-1", "", nil] {
            #expect(decide(session(agentSessionID: stored, owner: work.id), on: personal).switchTarget?.accountID == personal.id)
        }
    }

    @Test func aDeliberateSwitchFromAnUnknownOwnerBecomesASegment() {
        let settled = decide(session(owner: nil), on: personal, deliberate: true)
        #expect(settled.switchTarget?.accountID == personal.id)
    }

    @Test func aKnownOwnerThatMatchesChangesNothing() {
        #expect(decide(session(owner: work.id), on: work).changesNothing)
    }

    @Test func aFirstRecordOfAConversationWithoutHistoryIsNoSegment() {
        let recording = AgentSessionSettlement(recordedAccount: work.id, switchTarget: nil)
        #expect(decide(session(agentSessionID: nil, owner: nil), on: work) == recording)
        #expect(decide(session(agentSessionID: "", owner: nil), on: work) == recording)
        #expect(decide(session(agentSessionID: nil, owner: nil), on: work, deliberate: true) == recording)
    }

    @Test func aDeliberateSwitchBackToTheOwnerChangesNothingSoItsSessionIsResumed() {
        #expect(decide(session(owner: work.id), on: work, deliberate: true).changesNothing)
    }

    @Test func aConversationWithoutHistoryThatAlreadyNamesTheAccountChangesNothing() {
        #expect(decide(session(agentSessionID: nil, owner: work.id), on: work).changesNothing)
    }

    @Test func aQuestionNeverWritesAnythingNoMatterWhatTheSessionLooksLike() {
        #expect(decide(session(owner: work.id), on: personal, purpose: .answering).changesNothing)
        #expect(decide(session(owner: nil), on: personal, purpose: .answering, deliberate: true).changesNothing)
        #expect(decide(session(agentSessionID: nil), on: work, purpose: .answering).changesNothing)
    }

    @Test func anAgentWithoutAccountsChangesNothing() {
        #expect(decide(session(kind: .cursor, owner: work.id), on: nil).changesNothing)
    }

    @Test func theFailureToWriteSaysWhatItMeansForTheAgent() {
        let sentence = AgentSessionSettlement.writeFailure("disk full")
        #expect(sentence.contains("did not start the agent"))
        #expect(sentence.hasSuffix("disk full"))
    }

    @Test func aFailureToResolveTheAccountIsSaidWithItsReason() {
        #expect(AgentSessionSettlement.resolutionFailure("boom")
            == "Unified Dev could not work out which account to run under: boom")
    }

    @Test func aConversationIsResumedWhenTheLaunchRunsUnderTheAccountThatOwnsIt() {
        #expect(AgentSessionSettlement.resumable(session: session(owner: work.id), account: work) == "agent-session-1")
    }

    @Test func aConversationOwnedByAnotherAccountIsNotAskedOfTheCLIThatCannotSeeIt() {
        #expect(AgentSessionSettlement.resumable(session: session(owner: work.id), account: personal) == nil)
        #expect(AgentSessionSettlement.resumable(session: session(owner: work.id), account: defaultClaude) == nil)
    }

    @Test func aConversationWithNoRecordedOwnerIsResumedUnderWhicheverAccountRunsIt() {
        #expect(AgentSessionSettlement.resumable(session: session(owner: nil), account: personal) == "agent-session-1")
    }

    @Test func anAgentWithoutAccountsResumesItsConversationBecauseThereIsNoIsolationToBreak() {
        #expect(AgentSessionSettlement.resumable(session: session(owner: work.id), account: nil) == "agent-session-1")
    }

    @Test func aChatWithNoSegmentSaysSoRatherThanRunningUnguarded() {
        #expect(AgentSessionSettlement.noSegment.contains("did not start the agent"))
        #expect(!AgentSessionSettlement.noSegment.contains("native"))
    }
}
