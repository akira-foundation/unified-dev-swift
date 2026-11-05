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
        purpose: AgentSessionSettlement.Purpose = .sending
    ) -> AgentSessionSettlement {
        AgentSessionSettlement.decide(
            session: session, account: account, purpose: purpose
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

    private var workStandings: [AgentAccountStanding] {
        [
            AccountFixture.standing(work, email: "ada@client.example"),
            AccountFixture.standing(personal, email: "ada@home.example"),
        ]
    }

    @Test func aMoveToAnotherAccountNamesTheAccountItWentTo() {
        let settled = decide(session(owner: work.id), on: personal)
        let notice = settled.notice(on: personal, among: workStandings, besides: nil)

        #expect(notice?.contains("ada@home.example") == true)
        #expect(notice?.contains("history") == true)
    }

    @Test func aMoveToAnAccountWithNoStandingFallsBackToItsDirectory() {
        let settled = decide(session(owner: work.id), on: personal)
        let notice = settled.notice(on: personal, among: [], besides: nil)

        #expect(notice?.contains(personal.directory.lastPathComponent) == true)
    }

    @Test func nothingIsAnnouncedWhenTheChatDidNotMove() {
        let recorded = decide(session(agentSessionID: nil, owner: nil), on: work)

        #expect(recorded.notice(on: work, among: workStandings, besides: nil) == nil)
        #expect(AgentSessionSettlement.nothing.notice(on: work, among: workStandings, besides: nil) == nil)
    }

    @Test func aNoteAboutTheEnvironmentStaysBesideTheMove() {
        let moved = decide(session(owner: work.id), on: personal)
        let joined = moved.notice(on: personal, among: workStandings, besides: "Removed a key.")

        #expect(joined?.contains("ada@home.example") == true)
        #expect(joined?.hasSuffix("Removed a key.") == true)
        #expect(AgentSessionSettlement.nothing.notice(on: work, among: [], besides: "Removed a key.") == "Removed a key.")
    }

    @Test func aChangeOfAccountIsASegmentWithOrWithoutANativeSession() {
        for stored in ["agent-session-1", "", nil] {
            #expect(decide(session(agentSessionID: stored, owner: work.id), on: personal).switchTarget?.accountID == personal.id)
        }
    }

    @Test func aKnownOwnerThatMatchesChangesNothing() {
        #expect(decide(session(owner: work.id), on: work).changesNothing)
    }

    @Test func aFirstRecordOfAConversationWithoutHistoryIsNoSegment() {
        let recording = AgentSessionSettlement(recordedAccount: work.id, switchTarget: nil)
        #expect(decide(session(agentSessionID: nil, owner: nil), on: work) == recording)
        #expect(decide(session(agentSessionID: "", owner: nil), on: work) == recording)
    }

    @Test func aReturnToTheOwnerChangesNothingSoItsSessionIsResumed() {
        #expect(decide(session(owner: work.id), on: work).changesNothing)
    }

    @Test func aConversationWithoutHistoryThatAlreadyNamesTheAccountChangesNothing() {
        #expect(decide(session(agentSessionID: nil, owner: work.id), on: work).changesNothing)
    }

    @Test func aQuestionNeverWritesAnythingNoMatterWhatTheSessionLooksLike() {
        #expect(decide(session(owner: work.id), on: personal, purpose: .answering).changesNothing)
        #expect(decide(session(owner: nil), on: personal, purpose: .answering).changesNothing)
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
