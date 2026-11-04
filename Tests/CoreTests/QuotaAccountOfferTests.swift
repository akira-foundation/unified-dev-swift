import Testing
import Foundation
@testable import Core

@Suite("Offering another account when the allowance runs out")
struct QuotaAccountOfferTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let defaultClaude = AccountFixture.defaultClaude
    private let work = AccountFixture.work
    private let personal = AccountFixture.personal
    private let session = Session(workspaceID: nil, agentSessionID: "agent-session-1")

    private func standing(
        _ home: AgentAccountHome,
        email: String? = nil,
        report: AgentAccountLiveness.CliReport = .unanswered,
        exists: Bool = true
    ) -> AgentAccountStanding {
        AgentAccountStanding(
            home: home,
            identity: AgentAccountIdentity(email: email),
            cliReport: report,
            isolationDoubt: nil,
            directoryExists: exists
        )
    }

    private func spent(
        _ provider: AgentKind = .claudeCode,
        title: String = "Session",
        resets seconds: TimeInterval? = 7_500
    ) -> MenuBarPanelContent.LimitNotice {
        MenuBarPanelContent.LimitNotice(
            provider: provider, title: title, resetsAt: seconds.map { now.addingTimeInterval($0) }
        )
    }

    private func offer(
        current: AgentAccountHome? = nil,
        standings: [AgentAccountStanding]? = nil,
        notices: [MenuBarPanelContent.LimitNotice]? = nil,
        signedOut: AgentAccountSignOut.Cause? = nil,
        session: Session? = nil,
        isTurnInFlight: Bool = false,
        workspaceName: String = "billing"
    ) -> QuotaAccountOffer? {
        QuotaAccountOffer.make(QuotaAccountOffer.Input(
            session: session ?? self.session,
            current: current ?? defaultClaude,
            standings: standings ?? [
                standing(defaultClaude, email: "ada@home.example"),
                standing(work, email: "ada@client.example"),
            ],
            notices: notices ?? (signedOut == nil ? [spent()] : []),
            signedOut: signedOut,
            isTurnInFlight: isTurnInFlight,
            workspaceName: workspaceName,
            now: now
        ))
    }

    @Test func nothingIsOfferedWhileThereIsNothingWrongWithTheAccount() {
        #expect(offer(notices: []) == nil)
    }

    @Test func aSpentAllowanceOffersEveryOtherAccountOfTheSameAgent() {
        let made = offer()
        #expect(made?.choices.map(\.home.id) == [work.id])
        #expect(made?.choices.first?.button == "Restart this turn on ada@client.example")
    }

    @Test func theHeadlineNamesTheAccountAndWhenItResets() {
        #expect(offer()?.headline == "ada@home.example has no allowance left. It resets in 2h 5m.")
    }

    @Test func aDefaultAccountWithoutAnEmailIsCalledTheDefaultAccountInBothPlaces() {
        let made = offer(
            current: work,
            standings: [standing(defaultClaude), standing(work, email: "ada@client.example")]
        )
        #expect(made?.choices.first?.button == "Restart this turn on the default account")
        let reverse = offer(standings: [standing(defaultClaude), standing(work, email: "ada@client.example")])
        #expect(reverse?.headline.hasPrefix("The default account has no allowance left.") == true)
    }

    @Test func anAllowanceSpentOnAnotherAgentSaysNothingAboutThisSession() {
        #expect(offer(notices: [spent(.codex)]) == nil)
    }

    @Test func withNoOtherAccountThereIsNothingToOfferForASpentAllowance() {
        #expect(offer(standings: [standing(defaultClaude)]) == nil)
    }

    @Test func accountsOfAnotherAgentAreNeverOffered() {
        let codex = AccountFixture.extra("lab", provider: .codex)
        let made = offer(standings: [
            standing(defaultClaude), standing(codex), standing(work),
        ])
        #expect(made?.choices.map(\.home.id) == [work.id])
    }

    @Test func theAccountThatRanOutIsNeverOfferedToItself() {
        let made = offer(standings: [standing(defaultClaude), standing(work), standing(personal)])
        #expect(made?.choices.map(\.home.id) == [work.id, personal.id])
    }

    @Test func anAccountWhoseFolderIsGoneIsNotOffered() {
        let made = offer(standings: [standing(defaultClaude), standing(work, exists: false), standing(personal)])
        #expect(made?.choices.map(\.home.id) == [personal.id])
    }

    @Test func anAccountKnownToBeSignedOutIsNotOfferedAndTheNoteSaysSo() {
        let made = offer(standings: [
            standing(defaultClaude),
            standing(work, email: "ada@client.example", report: .claimsNoSession),
            standing(personal, email: "ada@lab.example"),
        ])
        #expect(made?.choices.map(\.home.id) == [personal.id])
        #expect(made?.notes.last == "ada@client.example is signed out, so it is not offered.")
    }

    @Test func ifEveryOtherAccountIsSignedOutThereIsNothingToOfferForASpentAllowance() {
        #expect(offer(standings: [standing(defaultClaude), standing(work, report: .claimsNoSession)]) == nil)
    }

    @Test func aTurnInFlightIsSaidToBeStoppedByTheButton() {
        let made = offer(isTurnInFlight: true)
        #expect(made?.choices.first?.button == "Stop this turn and restart it on ada@client.example")
        #expect(made?.choices.first?.losesTurnInFlight == true)
    }

    @Test func aTurnThatAlreadyEndedIsOnlyRestarted() {
        #expect(offer(isTurnInFlight: false)?.choices.first?.losesTurnInFlight == false)
    }

    @Test func theAccountComesBackWhenEverySpentWindowHasReset() {
        let made = offer(notices: [
            spent(title: "Weekly", resets: 90_000), spent(title: "Hourly", resets: 100), spent(title: "Session", resets: 3_000),
        ])
        #expect(made?.headline == "ada@home.example has no allowance left. It resets in 1d 1h.")
    }

    @Test func withoutAResetTimeForEverySpentWindowNoResetIsPromised() {
        let made = offer(notices: [spent(resets: 3_000), spent(title: "Weekly", resets: nil)])
        #expect(made?.headline == "ada@home.example has no allowance left.")
    }

    @Test func theNotesNeverPromiseTheConversationContinuesOrTheNextAccountWorks() {
        let words = (offer()?.notes ?? []).joined(separator: " ") + (offer()?.choices.first?.button ?? "")
        #expect(!words.localizedCaseInsensitiveContains("continue"))
        #expect(!words.localizedCaseInsensitiveContains("resume"))
        #expect(words.contains("cannot tell whether an account has allowance or a working sign-in"))
        #expect(words.contains("The agent starts without this conversation's history"))
    }

    @Test func theNotesSayWhichWorkspaceStaysOnTheNewAccount() {
        #expect(offer(workspaceName: "invoices")?.notes.first?.contains("keeps the invoices workspace on it") == true)
    }

    @Test func aSignOutIsOfferedEvenWhenNoOtherAccountExistsAndSaysHowToGetBack() {
        let made = offer(standings: [standing(defaultClaude, email: "ada@home.example")], signedOut: .notSignedIn)
        #expect(made?.choices.isEmpty == true)
        #expect(made?.headline.contains("is not signed in") == true)
        #expect(made?.notes == [AgentAccountSignOut.recovery(provider: .claudeCode)])
    }

    @Test func aSignOutTakesPrecedenceOverASpentAllowance() {
        let made = offer(notices: [spent()], signedOut: .afterSwitch)
        #expect(made?.headline.contains("may have cost it") == true)
    }

    @Test func aSignOutStillOffersTheOtherAccountsThatAreSignedIn() {
        let made = offer(signedOut: .notSignedIn)
        #expect(made?.choices.map(\.home.id) == [work.id])
    }

    @Test func theCurrentAccountIsNeverNamedAsSignedOutEvenWhenItsOwnStandingSaysSo() {
        let made = offer(standings: [
            standing(defaultClaude, email: "ada@home.example", report: .claimsNoSession),
            standing(work, email: "ada@client.example"),
        ])
        #expect(made?.choices.map(\.home.id) == [work.id])
        #expect(made?.notes.contains { $0.contains("ada@home.example is signed out") } == false)
    }

    @Test func twoSignedOutAccountsAreNamedInThePlural() {
        let made = offer(standings: [
            standing(defaultClaude),
            standing(work, email: "ada@a.example", report: .claimsNoSession),
            standing(personal, email: "ada@b.example", report: .claimsNoSession),
            standing(AccountFixture.extra("lab"), email: "ada@lab.example"),
        ])
        #expect(made?.notes.last == "ada@a.example and ada@b.example are signed out, so they are not offered.")
    }

    @Test func whenEveryOtherAccountIsSignedOutTheRecoveryDoesNotSendTheOwnerToAnotherAccount() {
        let made = offer(
            standings: [standing(defaultClaude), standing(work, email: "ada@client.example", report: .claimsNoSession)],
            signedOut: .notSignedIn
        )
        #expect(made?.choices.isEmpty == true)
        #expect(made?.notes == [
            AgentAccountSignOut.recovery(provider: .claudeCode),
            "ada@client.example is signed out, so it is not offered.",
        ])
        #expect(made?.notes.joined().contains("another account") == false)
    }

    @Test func anOfferedAccountWhoseIsolationIsDoubtedCarriesTheDoubt() {
        let doubtful = AgentAccountStanding(
            home: work,
            identity: AgentAccountIdentity(email: "ada@client.example"),
            cliReport: .unanswered,
            isolationDoubt: "Its login lives in the system keychain.",
            directoryExists: true
        )
        let made = offer(standings: [standing(defaultClaude), doubtful])
        #expect(made?.notes.contains("ada@client.example: Its login lives in the system keychain.") == true)
    }

    @Test func aDoubtAboutTheDefaultAccountIsNotRaisedBecauseTheDefaultIsNeverSeparated() {
        let doubtfulDefault = AgentAccountStanding(
            home: defaultClaude,
            identity: AgentAccountIdentity(email: "ada@home.example"),
            cliReport: .unanswered,
            isolationDoubt: "Its login lives in the system keychain.",
            directoryExists: true
        )
        let made = offer(current: work, standings: [doubtfulDefault, standing(work, email: "ada@client.example")])
        #expect(made?.choices.map(\.home.id) == [defaultClaude.id])
        #expect(made?.notes.contains { $0.contains("keychain") } == false)
    }

    @Test func aDoubtAboutAnAccountThatIsNotOfferedIsNotRaised() {
        let doubtful = AgentAccountStanding(
            home: work,
            identity: AgentAccountIdentity(email: "ada@client.example"),
            cliReport: .claimsNoSession,
            isolationDoubt: "Its login lives in the system keychain.",
            directoryExists: true
        )
        let made = offer(standings: [standing(defaultClaude), doubtful, standing(personal)])
        #expect(made?.notes.contains { $0.contains("keychain") } == false)
    }

    @Test func theMessageNoteSaysAttachedFilesComeAlongOnlyIfTheyAreStillThere() {
        let note = offer()?.notes.first ?? ""
        #expect(note.contains("Starts this turn's message again"))
        #expect(note.contains("with its attached files if they are still where they were"))
    }

    @Test func aSessionThatNamesAnotherAccountThanTheOneOnScreenIsOfferedNothing() {
        var elsewhere = session
        elsewhere.accountID = personal.id
        #expect(offer(session: elsewhere) == nil)
    }

    @Test func aSessionThatNamesTheAccountOnScreenIsOfferedTheSwitch() {
        var named = session
        named.accountID = defaultClaude.id
        #expect(offer(session: named)?.choices.map(\.home.id) == [work.id])
    }

    @Test func aSessionOfAnotherAgentThanTheAccountIsGivenNothing() {
        let codexSession = Session(workspaceID: nil, agentSessionID: "x", agentKind: .codex)
        #expect(offer(session: codexSession) == nil)
    }
}
