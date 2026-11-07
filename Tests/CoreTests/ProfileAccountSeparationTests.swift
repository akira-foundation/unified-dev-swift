import Testing
import Foundation
@testable import Core

@Suite("What one profile's agents can reach", .tags(.persistence), .scratchDirectory)
struct ProfileAccountSeparationTests {
    private let user = URL(filePath: "/Users/someone")

    private var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }

    private func account(_ name: String, in profile: ProfileID = .initial) throws -> AgentAccountRow {
        let path = TestScratch.unique("accounts") + "/" + name
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return AgentAccountRow(id: AgentAccountID(name), provider: .claudeCode, directory: path, profileID: profile)
    }

    private func repo(_ store: Store, in profile: ProfileID) async throws -> Repo {
        try await store.upsert(Repo(name: "site", path: TestScratch.unique("repo"), profileID: profile))
    }

    @Test("a profile with accounts of its own lists none of Unified's and says it runs outside them")
    func anOwnProfileIsSeparated() async throws {
        let store = try makeTestStore("profile-separation")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[1], symbol: "star")
        let site = try await repo(store, in: akira.id)
        let shared = try account("shared")
        let client = try account("client", in: akira.id)
        for row in [shared, client] { try await store.add(row) }
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(shared)), forRepo: site.id)

        let resolution = try await AgentAccountResolver.resolve(
            workspaceID: nil, repoID: site.id, store: store, defaults: [defaultClaude]
        )
        let choice = resolution.choice(for: .claudeCode)

        #expect(Set(resolution.standings.map(\.home.id)) == [defaultClaude.id, client.id])
        #expect(resolution.runsOutsideProfile)
        #expect(choice.isProjectChoiceLost)
        #expect(choice.home?.id == defaultClaude.id)
    }

    @Test("a profile that uses Unified's lists Unified's and runs inside them")
    func anInheritingProfileSeesUnified() async throws {
        let store = try makeTestStore("profile-separation")
        let heir = try await store.createProfile(name: "Heir", colour: Accent.all[1], symbol: "star", accounts: .inherits)
        let site = try await repo(store, in: heir.id)
        let shared = try account("shared")
        try await store.add(shared)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(shared)), forRepo: site.id)

        let resolution = try await AgentAccountResolver.resolve(
            workspaceID: nil, repoID: site.id, store: store, defaults: [defaultClaude]
        )

        #expect(Set(resolution.standings.map(\.home.id)) == [defaultClaude.id, shared.id])
        #expect(!resolution.runsOutsideProfile)
        #expect(resolution.home(for: .claudeCode)?.id == shared.id)
    }

    @Test("a profile that turns to Unified's clears its projects' choices of its own accounts")
    func turningToInheritClearsOwnChoices() async throws {
        let store = try makeTestStore("profile-separation")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[1], symbol: "star")
        let site = try await repo(store, in: akira.id)
        let client = try account("client", in: akira.id)
        try await store.add(client)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(client)), forRepo: site.id)

        let cleared = try await store.setAccountSource(.inherits, for: akira.id)
        let resolution = try await AgentAccountResolver.resolve(
            workspaceID: nil, repoID: site.id, store: store, defaults: [defaultClaude]
        )

        #expect(cleared == [site.id])
        #expect(try await store.agentAccountChoices().repos[site.id] == nil)
        #expect(!resolution.standings.map(\.home.id).contains(client.id))
    }

    @Test("a project's choice of this Mac's own login is not cleared when its profile has accounts of its own")
    func theMacLoginIsNeverAStrayChoice() async throws {
        let store = try makeTestStore("profile-separation")
        let heir = try await store.createProfile(name: "Heir", colour: Accent.all[1], symbol: "star", accounts: .inherits)
        let site = try await repo(store, in: heir.id)
        try await AgentAccountAssignment.choose(ChosenAgentAccount(defaultClaude), forRepo: site.id, in: store)

        let cleared = try await store.setAccountSource(.own, for: heir.id)

        #expect(cleared.isEmpty)
        #expect(try await store.agentAccountChoices().repos[site.id] == [.claudeCode: defaultClaude.id])
    }

    @Test("an agent running under an account its profile cannot reach does not block that account's removal")
    func anUnreachableChoiceIsNotInUse() async throws {
        let store = try makeTestStore("profile-separation")
        let akira = try await store.createProfile(name: "Akira", colour: Accent.all[1], symbol: "star")
        let site = try await repo(store, in: .initial)
        let workspace = try await store.upsert(Workspace(
            repoID: site.id, name: "billing", branch: "b", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let client = try account("client", in: akira.id)
        try await store.add(client)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(client)), forRepo: site.id)
        var session = Session(workspaceID: workspace.id)
        session.apply(.turnStarted)
        try await store.upsert(session)

        let users = try await AgentAccountUsage.runningWorkspaces(
            under: AgentAccountHome(client), store: store, defaults: [defaultClaude]
        )

        #expect(users.isEmpty)
    }

    @Test("a new profile created to use Unified's is stored that way in one write")
    func creatingAnInheritingProfile() async throws {
        let store = try makeTestStore("profile-separation")
        let heir = try await store.createProfile(name: "Heir", colour: Accent.all[1], symbol: "star", accounts: .inherits)
        #expect(try await store.profileAccounts().source(of: heir.id) == .inherits)
    }

    @Test("the fingerprint changes when only where a profile's accounts come from changes")
    func fingerprintFollowsTheHolder() {
        let heir = ProfileID("heir")
        let repoID = RepoID("r")
        let scope = AccountScope(repoID: repoID)
        let own = AgentAccountChoiceBook(repoProfiles: [repoID: heir], accounts: ProfileAccounts(sources: [heir: .own]))
        let inherits = AgentAccountChoiceBook(
            repoProfiles: [repoID: heir], accounts: ProfileAccounts(sources: [heir: .inherits])
        )

        #expect(AccountFingerprint.make(scope: scope, book: own, repoID: nil)
            != AccountFingerprint.make(scope: scope, book: inherits, repoID: nil))
    }

    @Test("Settings shows a profile that uses Unified's with Unified's default and Unified's name")
    func ownerOfAnInheritingProfile() {
        let unified = Profile(id: .initial, name: "Unified", folder: "unified", colour: Accent.all[0], symbol: "star")
        let heir = Profile(id: ProfileID("heir"), name: "Heir", folder: "heir", colour: Accent.all[1], symbol: "star")
        let book = AgentAccountChoiceBook(
            profiles: [.initial: [.claudeCode: AgentAccountID("shared")], heir.id: [.claudeCode: AgentAccountID("stale")]],
            accounts: ProfileAccounts(sources: [heir.id: .inherits])
        )

        let owner = AgentAccountPanel.Owner.make(
            for: .claudeCode, in: heir.id, profiles: [unified, heir], book: book, standings: []
        )

        #expect(owner.name == "Heir")
        #expect(owner.holderName == "Unified")
        #expect(owner.inherits)
        #expect(!owner.refusesWithoutAccount)
        #expect(owner.defaultAccount == AgentAccountID("shared"))
    }

    @Test("the spend of this Mac's own login stays on the board of a profile with accounts of its own")
    func macLoginSpendStays() {
        let akira = ProfileID("akira")
        let accounts = ProfileAccounts(sources: [akira: .own])
        let lines = [
            SpendAccountLine(accountID: defaultClaude.id, name: "login", provider: .claudeCode, spend: Spend(), sessions: []),
            SpendAccountLine(accountID: AgentAccountID("shared"), name: "shared", provider: .claudeCode, spend: Spend(), sessions: []),
        ]
        #expect(accounts.spendLines(lines, in: akira).map(\.name) == ["login"])
    }
}
