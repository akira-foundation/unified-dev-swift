import Testing
import Foundation
@testable import Core

@Suite("Agent account names")
struct AgentAccountNamesTests {
        @Test func anAccountIsNamedByItsEmail() {
        let standings = [AccountFixture.standing(AccountFixture.defaultClaude), AccountFixture.standing(AccountFixture.work, email: "me@client.com")]
        #expect(AgentAccountNames.title(of: standings[1], among: standings) == "me@client.com")
    }

    @Test func aSignedOutDefaultAccountIsCalledTheDefaultAccount() {
        let standings = [AccountFixture.standing(AccountFixture.defaultClaude)]
        #expect(AgentAccountNames.title(of: standings[0], among: standings) == "Default account")
    }

    @Test func aSignedOutAccountTheAppMadeIsNamedByItsDirectory() {
        let standings = [AccountFixture.standing(AccountFixture.work)]
        #expect(AgentAccountNames.title(of: standings[0], among: standings) == "work")
    }

    @Test func twoAccountsWithTheSameEmailAreToldApartByTheirDirectory() {
        let standings = [
            AccountFixture.standing(AccountFixture.defaultClaude, email: "a@b.c"),
            AccountFixture.standing(AccountFixture.work, email: "a@b.c"),
        ]
        let titles = standings.map { AgentAccountNames.title(of: $0, among: standings) }
        #expect(titles == ["a@b.c (default)", "a@b.c (work)"])
    }

    @Test func theSameEmailOnAnotherAgentIsNotACollision() {
        let standings = [
            AccountFixture.standing(AccountFixture.defaultClaude, email: "a@b.c"),
            AccountFixture.standing(AccountFixture.defaultCodex, email: "a@b.c"),
        ]
        #expect(AgentAccountNames.title(of: standings[0], among: standings) == "a@b.c")
    }

    @Test func aHomeThatTheRosterDoesNotKnowHasNoName() {
        #expect(AgentAccountNames.title(of: AccountFixture.work, among: [AccountFixture.standing(AccountFixture.defaultClaude)]) == nil)
    }

    @Test func aTitleIsTheSameWhetherItIsAskedOfAStandingOrOfAHomeWithItsIdentity() {
        let identity = AgentAccountIdentity(email: "me@client.com")
        let entries = [
            AgentAccountNames.Entry(home: AccountFixture.defaultClaude, identity: nil),
            AgentAccountNames.Entry(home: AccountFixture.work, identity: identity),
        ]
        let standings = [AccountFixture.standing(AccountFixture.defaultClaude), AccountFixture.standing(AccountFixture.work, email: "me@client.com")]

        #expect(entries.map { AgentAccountNames.title(of: $0, among: entries) } == standings.map { AgentAccountNames.title(of: $0, among: standings) })
    }

    @Test func theDefaultAccountIsReferredToWithAnArticleAndAnythingElseByItsName() {
        #expect(AgentAccountNames.reference(to: "Default account") == "the default account")
        #expect(AgentAccountNames.reference(to: "me@client.com") == "me@client.com")
        #expect(AgentAccountNames.reference(to: "work") == "work")
    }
}
