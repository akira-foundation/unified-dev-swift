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
        #expect(identity?.authMethod == .subscription)
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
        #expect(twice.problems.contains { $0.contains("two accounts") })
        #expect(scenario([.init(email: " ")]).problems.contains { $0.contains("no email") })
        #expect(
            scenario([.init(provider: .grok, email: "a@b.c")]).problems
                .contains { $0.contains("no identity on disk") }
        )
    }
}
