import Testing
import Foundation
@testable import Core

@Suite("Resuming an agent session under the account that owns it")
struct AgentSessionResumeTests {
    private let defaultClaude = AccountFixture.defaultClaude
    private let work = AccountFixture.work
    private let personal = AccountFixture.personal
    private let defaultCodex = AccountFixture.defaultCodex

    private func session(
        agentSessionID: String? = "agent-session-1",
        kind: AgentKind = .claudeCode,
        owner: AgentAccountID? = nil
    ) -> Session {
        var made = Session(workspaceID: nil, agentSessionID: agentSessionID, agentKind: kind)
        made.accountID = owner
        return made
    }

    @Test func aSessionThatNeverSpokeStartsInsteadOfResuming() {
        #expect(AgentSessionResume.decide(session: session(agentSessionID: nil), running: work) == .start)
        #expect(AgentSessionResume.decide(session: session(agentSessionID: ""), running: work) == .start)
    }

    @Test func aSessionResumesUnderTheAccountItWasStartedOn() {
        let started = session(owner: work.id)
        #expect(AgentSessionResume.decide(session: started, running: work) == .resume("agent-session-1"))
    }

    @Test func aSessionStartedUnderOneAccountDoesNotResumeUnderAnother() {
        let started = session(owner: work.id)
        #expect(AgentSessionResume.decide(session: started, running: personal) == .fresh)
    }

    @Test func aSessionFromBeforeAccountsBelongsToTheDefaultAccountOfItsProvider() {
        let legacy = session()
        #expect(AgentSessionResume.decide(session: legacy, running: defaultClaude) == .resume("agent-session-1"))
        #expect(AgentSessionResume.decide(session: legacy, running: work) == .fresh)
    }

    @Test func theDefaultAccountAThirdPartySessionBelongsToIsItsOwnProvidersDefault() {
        let legacy = session(kind: .codex)
        #expect(AgentSessionResume.decide(session: legacy, running: defaultCodex) == .resume("agent-session-1"))
    }

    @Test func anAgentWithoutAccountsResumesAsItAlwaysDid() {
        let started = session(kind: .cursor, owner: work.id)
        #expect(AgentSessionResume.decide(session: started, running: nil) == .resume("agent-session-1"))
    }

    @Test func onlyAResumeCarriesAnAgentSessionID() {
        #expect(AgentSessionResume.resume("x").agentSessionID == "x")
        #expect(AgentSessionResume.fresh.agentSessionID == nil)
        #expect(AgentSessionResume.start.agentSessionID == nil)
    }

    @Test func theAccountIsRecordedWhenTheSessionDoesNotNameItYet() {
        #expect(AgentSessionResume.recordedAccount(for: session(owner: nil), running: work) == work.id)
        #expect(AgentSessionResume.recordedAccount(for: session(owner: personal.id), running: work) == work.id)
    }

    @Test func nothingIsRecordedWhenTheSessionAlreadyNamesTheAccountOrThereIsNone() {
        #expect(AgentSessionResume.recordedAccount(for: session(owner: work.id), running: work) == nil)
        #expect(AgentSessionResume.recordedAccount(for: session(owner: work.id), running: nil) == nil)
    }

    @Test func theNoticeNamesTheAgentAndSaysTheTranscriptStays() {
        let notice = AgentSessionResume.freshNotice(for: .codex)
        #expect(notice.contains("Codex"))
        #expect(notice.contains("transcript here is unchanged"))
    }
}
