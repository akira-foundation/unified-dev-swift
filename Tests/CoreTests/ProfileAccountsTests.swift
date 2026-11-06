import Testing
import Foundation
@testable import Core

@Suite("Profile accounts")
struct ProfileAccountsTests {
    private let akira = ProfileID("akira")
    private let heir = ProfileID("heir")

    private var accounts: ProfileAccounts {
        ProfileAccounts(
            owners: [AccountFixture.work.id: akira, AccountFixture.personal.id: .initial],
            sources: [akira: .own, heir: .inherits]
        )
    }

    private var standings: [AgentAccountStanding] {
        [AccountFixture.defaultClaude, AccountFixture.work, AccountFixture.personal].map { AccountFixture.standing($0) }
    }

    @Test("a profile that inherits holds Unified's accounts, and Unified never inherits")
    func holders() {
        let unifiedInherits = ProfileAccounts(sources: [.initial: .inherits])
        #expect(accounts.holder(for: heir) == .initial)
        #expect(accounts.holder(for: akira) == akira)
        #expect(unifiedInherits.holder(for: .initial) == .initial)
        #expect(accounts.source(of: ProfileID("unknown")) == .own)
    }

    @Test("a profile lists only the accounts it holds, and the Mac's own login only in Unified")
    func listing() {
        #expect(accounts.listed(standings, in: akira).map(\.home.id) == [AccountFixture.work.id])
        #expect(accounts.listed(standings, in: .initial).map(\.home.id) == [
            AccountFixture.defaultClaude.id, AccountFixture.personal.id,
        ])
        #expect(accounts.listed(standings, in: heir).map(\.home.id) == [
            AccountFixture.defaultClaude.id, AccountFixture.personal.id,
        ])
    }

    @Test("the Mac's own login is reachable from every profile, so an agent always has something to run")
    func reaching() {
        #expect(accounts.reachable(standings, from: akira).map(\.home.id) == [
            AccountFixture.defaultClaude.id, AccountFixture.work.id,
        ])
    }

    @Test("a choice of an account the profile does not hold is a stray, per agent, and this Mac's own login never is")
    func strays() {
        let chosen: [AgentKind: AgentAccountID] = [
            .claudeCode: AccountFixture.personal.id, .codex: AccountFixture.defaultCodex.id,
        ]
        #expect(accounts.strayChoices(chosen, in: akira) == [.claudeCode])
        #expect(accounts.strayChoices(chosen, in: heir).isEmpty)
        #expect(accounts.strayChoices([.claudeCode: AccountFixture.work.id], in: akira).isEmpty)
    }

    @Test("an existing account goes to the one profile whose projects chose it, and to Unified otherwise")
    func migratedOwners() {
        let site = RepoID("site")
        let shop = RepoID("shop")
        let home = RepoID("home")
        let profiles = [site: akira, shop: akira, home: ProfileID.initial]
        let one: [RepoID: [AgentKind: AgentAccountID]] = [site: [.claudeCode: AgentAccountID("a")], shop: [.codex: AgentAccountID("a")]]
        let split: [RepoID: [AgentKind: AgentAccountID]] = [site: [.claudeCode: AgentAccountID("a")], home: [.claudeCode: AgentAccountID("a")]]

        #expect(ProfileAccounts.migratedOwner(of: AgentAccountID("a"), repoChoices: one, repoProfiles: profiles) == akira)
        #expect(ProfileAccounts.migratedOwner(of: AgentAccountID("a"), repoChoices: split, repoProfiles: profiles) == .initial)
        #expect(ProfileAccounts.migratedOwner(of: AgentAccountID("a"), repoChoices: [:], repoProfiles: profiles) == .initial)
    }

    @Test("a profile that received no account in the migration inherits, so its agents keep running as before")
    func migratedSources() {
        let owners = [AgentAccountID("a"): akira]
        #expect(ProfileAccounts.migratedSource(of: akira, owners: owners) == .own)
        #expect(ProfileAccounts.migratedSource(of: heir, owners: owners) == .inherits)
        #expect(ProfileAccounts.migratedSource(of: .initial, owners: owners) == .own)
    }

    @Test("the choice book reads the profile level from the profile that holds the accounts")
    func bookFollowsTheHolder() {
        let book = AgentAccountChoiceBook(
            repos: [RepoID("r"): [.codex: AgentAccountID("own")]],
            profiles: [.initial: [.claudeCode: AccountFixture.personal.id], heir: [.claudeCode: AgentAccountID("stale")]],
            repoProfiles: [RepoID("r"): heir],
            accounts: accounts
        )
        let choices = book.choices(repoID: RepoID("r"))
        let home = book.choices(repoID: nil, profileID: heir)

        #expect(choices.profile == [.claudeCode: AccountFixture.personal.id])
        #expect(choices.project == [.codex: AgentAccountID("own")])
        #expect(home.profile == [.claudeCode: AccountFixture.personal.id])
    }

    @Test("the spend of accounts outside the active profile is left out, and spend with no account stays in Unified")
    func spendLines() {
        let lines = [
            SpendAccountLine(accountID: AccountFixture.work.id, name: "work", provider: .claudeCode, spend: Spend(), sessions: []),
            SpendAccountLine(accountID: AccountFixture.personal.id, name: "personal", provider: .claudeCode, spend: Spend(), sessions: []),
            SpendAccountLine(accountID: nil, name: "unknown", provider: .codex, spend: Spend(), sessions: []),
        ]
        #expect(accounts.spendLines(lines, in: akira).map(\.name) == ["work"])
        #expect(accounts.spendLines(lines, in: .initial).map(\.name) == ["personal", "unknown"])
    }

    @Test("a profile's turns are the ones run in its projects, and turns outside every project are Unified's")
    func spendDays() {
        let site = Repo(name: "site", path: "/code/site", profileID: akira)
        let day = { (directory: String) in
            SpendDay(
                provider: .claudeCode, day: Date(timeIntervalSince1970: 0), model: "m", directory: directory,
                file: directory, usage: TokenUsage(), turns: 1, tier: .base
            )
        }
        let days = [day("/code/site/src"), day("/tmp/elsewhere")]

        #expect(SpendProjects.days(days, in: akira, workspaces: [], repos: [site]).map(\.directory) == ["/code/site/src"])
        #expect(SpendProjects.days(days, in: .initial, workspaces: [], repos: [site]).map(\.directory) == ["/tmp/elsewhere"])
    }

}
