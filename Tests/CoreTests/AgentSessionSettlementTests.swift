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

    @Test func aKnownOwnerThatDiffersKeepsTheStoredIDAndTheRecordedAccountAndSaysSo() {
        let settled = decide(session(owner: work.id), on: personal)
        #expect(!settled.clearsStoredID)
        #expect(settled.recordedAccount == nil)
        #expect(settled.notice == AgentSessionSettlement.elsewhereNotice(for: .claudeCode))
    }

    @Test func onlyADeliberateSwitchEverClearsTheStoredID() {
        for owner in [work.id, personal.id, nil] {
            #expect(!decide(session(owner: owner), on: personal).clearsStoredID)
            #expect(decide(session(owner: owner), on: personal, deliberate: true).clearsStoredID)
        }
    }

    @Test func aKnownOwnerThatMatchesChangesNothing() {
        #expect(decide(session(owner: work.id), on: work).changesNothing)
    }

    @Test func aDeliberateSwitchClearsTheStoredIDEvenWhenTheOwnerWasNeverRecordedAndSaysNothing() {
        let settled = decide(session(owner: nil), on: work, deliberate: true)
        #expect(settled.clearsStoredID)
        #expect(settled.recordedAccount == work.id)
        #expect(settled.notice == nil)
    }

    @Test func aConversationWithoutHistoryOnlyRecordsItsAccountAndNeverClearsOrWarns() {
        let settled = decide(session(agentSessionID: nil, owner: nil), on: work)
        #expect(settled == AgentSessionSettlement(clearsStoredID: false, notice: nil, recordedAccount: work.id))
        let empty = decide(session(agentSessionID: "", owner: personal.id), on: work)
        #expect(empty == AgentSessionSettlement(clearsStoredID: false, notice: nil, recordedAccount: work.id))
    }

    @Test func aDeliberateSwitchOfAConversationWithoutHistoryOnlyRecordsTheAccount() {
        let settled = decide(session(agentSessionID: nil, owner: nil), on: work, deliberate: true)
        #expect(settled == AgentSessionSettlement(clearsStoredID: false, notice: nil, recordedAccount: work.id))
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

    @Test func theNoticeNamesTheAgentAndSaysTheChatWasLeftWhereItIs() {
        let notice = AgentSessionSettlement.elsewhereNotice(for: .codex)
        #expect(notice.contains("Codex"))
        #expect(notice.contains("left it there"))
    }
}
