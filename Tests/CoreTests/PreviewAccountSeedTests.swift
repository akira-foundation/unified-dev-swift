import Testing
import Foundation
@testable import Core

private func scenario(_ accounts: [PreviewScenario.Account]) -> PreviewScenario {
    PreviewScenario(projects: [PreviewScenario.Project(name: "billing")], accounts: accounts)
}

private func seeder() throws -> PreviewScenarioSeeder {
    PreviewScenarioSeeder(
        manager: WorkspaceManager(store: try makeTestStore("preview-accounts")),
        scratchRoot: TestScratch.unique("preview-scratch")
    )
}

@Suite("Preview account seeding")
struct PreviewAccountSeedTests {
    private let now = Date(timeIntervalSince1970: 1_791_676_800)

    @Test("a scenario that names accounts with no home to write into is refused")
    func withoutAnOverrideNothingIsWritten() throws {
        let made = try seeder()
        #expect(throws: PreviewScenarioError.noTranscriptHome) {
            try made.seedAgentAccounts(scenario([.init(email: "ada@lovelace.dev")]), home: nil, at: now)
        }
    }

    @Test("a scenario with no accounts needs no home")
    func noAccountsNeedsNoHome() throws {
        #expect(try seeder().seedAgentAccounts(scenario([]), home: nil, at: now) == 0)
    }

    @Test("a seeded Claude account is read back as the email the scenario named")
    func seededClaudeAccountIsRead() throws {
        let home = URL(filePath: TestScratch.unique("account-home"), directoryHint: .isDirectory)
        let written = try seeder().seedAgentAccounts(
            scenario([.init(email: "ada@lovelace.dev", organisation: "Lantern", plan: "Max")]),
            home: home,
            at: now
        )
        #expect(written == 1)

        let place = AgentAccountHome.defaultHome(for: .claudeCode, home: home)!
        let identity = AgentAccountIdentities.read([place])[place.id]
        #expect(identity?.email == "ada@lovelace.dev")
        #expect(identity?.organisationName == "Lantern")
        #expect(identity?.plan == "Max")
        #expect(identity?.isEmpty == false)
    }

    @Test("a seeded Claude account can carry either rate limit tier")
    func seededClaudeAccountCarriesATier() throws {
        for (tier, plan) in [("default_claude_max_20x", "Ultra"), ("default_claude_max_5x", "Max")] {
            let home = URL(filePath: TestScratch.unique("account-home"), directoryHint: .isDirectory)
            _ = try seeder().seedAgentAccounts(
                scenario([.init(email: "ada@lovelace.dev", plan: "max", rateLimitTier: tier)]),
                home: home,
                at: now
            )
            let place = AgentAccountHome.defaultHome(for: .claudeCode, home: home)!
            #expect(AgentAccountIdentities.read([place])[place.id]?.plan == plan)
        }
    }

    @Test("a seeded Claude account with no tier still reads as the plan the scenario named")
    func seededClaudeAccountWithoutATier() throws {
        let home = URL(filePath: TestScratch.unique("account-home"), directoryHint: .isDirectory)
        _ = try seeder().seedAgentAccounts(scenario([.init(email: "ada@lovelace.dev")]), home: home, at: now)
        let place = AgentAccountHome.defaultHome(for: .claudeCode, home: home)!
        #expect(AgentAccountIdentities.read([place])[place.id]?.plan == "Max")
    }

    @Test("a scenario account decodes its tier, and reads without one")
    func accountDecodesATier() throws {
        let tiered = try JSONDecoder().decode(
            PreviewScenario.Account.self,
            from: Data(#"{"email":"a@b.c","rateLimitTier":"default_claude_max_20x"}"#.utf8)
        )
        let plain = try JSONDecoder().decode(PreviewScenario.Account.self, from: Data(#"{"email":"a@b.c"}"#.utf8))
        #expect(tiered.rateLimitTier == "default_claude_max_20x")
        #expect(plain.rateLimitTier == nil)
    }

    @Test("a seeded Codex account is read back from the one file that serves both roles")
    func seededCodexAccountIsRead() throws {
        let home = URL(filePath: TestScratch.unique("account-home"), directoryHint: .isDirectory)
        _ = try seeder().seedAgentAccounts(
            scenario([.init(provider: .codex, email: "ada@lovelace.dev", plan: "pro")]),
            home: home,
            at: now
        )

        let place = AgentAccountHome.defaultHome(for: .codex, home: home)!
        let identity = AgentAccountIdentities.read([place])[place.id]
        #expect(identity?.email == "ada@lovelace.dev")
        #expect(identity?.plan == "Pro 20x")
        #expect(identity?.expiresAt ?? now > now)
    }

    @Test("a seeded account carries no credential of its own")
    func noCredentialIsWritten() throws {
        let home = URL(filePath: TestScratch.unique("account-home"), directoryHint: .isDirectory)
        _ = try seeder().seedAgentAccounts(
            scenario([
                .init(email: "ada@lovelace.dev"),
                .init(provider: .codex, email: "ada@lovelace.dev"),
            ]),
            home: home,
            at: now
        )

        for place in [AgentAccountHome.defaultHome(for: .claudeCode, home: home)!,
                      AgentAccountHome.defaultHome(for: .codex, home: home)!] {
            let body = String(data: try Data(contentsOf: place.credentialPath), encoding: .utf8) ?? ""
            #expect(!body.contains("access_token"))
            #expect(!body.contains("refresh_token"))
            #expect(!body.contains("accessToken"))
        }
    }

    @Test("a scenario naming an account twice for one agent, or with no email, is refused")
    func problemsAreReported() {
        let twice = scenario([.init(email: "a@b.c"), .init(email: "d@e.f")])
        #expect(twice.problems.contains { $0.contains("two default accounts") })
        #expect(scenario([.init(email: " ")]).problems.contains { $0.contains("no email") })
        #expect(
            scenario([.init(provider: .grok, email: "a@b.c")]).problems
                .contains { $0.contains("no identity on disk") }
        )
    }

    @Test("a labelled account and a project's choice of it are refused when they do not add up")
    func labelledAccountProblemsAreReported() {
        let client = PreviewScenario.Account(email: "a@b.c", label: "client")
        let twice = scenario([client, client])
        #expect(twice.problems.contains { $0.contains("account \"client\" is declared twice") })
        #expect(scenario([.init(email: "a@b.c", missing: true)]).problems.contains { $0.contains("cannot be missing") })
        #expect(scenario([.init(email: "a@b.c", label: "a/b")]).problems.contains { $0.contains("plain folder name") })

        let choosing = PreviewScenario(
            projects: [PreviewScenario.Project(name: "billing", accounts: ["claudeCode": "lab", "nobody": "client"])],
            accounts: [client]
        )
        #expect(choosing.problems.contains { $0.contains("chooses Claude Code account \"lab\"") })
        #expect(choosing.problems.contains { $0.contains("\"nobody\", which is no agent") })
    }

    @Test("a labelled account is added beside the default and the project runs it")
    func aLabelledAccountIsAddedAndChosen() async throws {
        let home = URL(filePath: TestScratch.unique("account-home"), directoryHint: .isDirectory)
        let made = try seeder()
        let store = made.manager.store
        let repo = try await store.upsert(Repo(name: "billing", path: TestScratch.unique("repo")))
        let seeded = PreviewScenario(
            projects: [PreviewScenario.Project(name: "billing", accounts: ["claudeCode": "client"])],
            accounts: [
                .init(email: "ada@home.invalid"),
                .init(email: "ada@client.invalid", label: "client"),
                .init(email: "ada@gone.invalid", label: "gone", missing: true),
            ]
        )

        #expect(try made.seedAgentAccounts(seeded, home: home, at: now) == 3)
        try await made.seedAccountChoices(seeded, repos: ["billing": repo.id], home: home)

        let client = try #require(PreviewScenarioSeeder.place(of: seeded.accounts[1], home: home))
        let gone = try #require(PreviewScenarioSeeder.place(of: seeded.accounts[2], home: home))
        #expect(AgentAccountIdentities.read([client])[client.id]?.email == "ada@client.invalid")
        #expect(!FileManager.default.fileExists(atPath: gone.directory.path))
        #expect(Set(try await store.agentAccounts().map(\.id)).isSuperset(of: [client.id, gone.id]))
        #expect(try await store.agentAccountChoices().repos[repo.id] == [.claudeCode: client.id])
    }
}
