import Testing
import Foundation
@testable import Core

@Suite("Agent account home")
struct AgentAccountHomeTests {
    @Test func defaultClaudeHomeKeepsIdentityInTheHomeDirectory() {
        let home = URL(filePath: "/Users/someone")
        let account = AgentAccountHome.defaultHome(for: .claudeCode, home: home)
        #expect(account?.directory.path == "/Users/someone/.claude")
        #expect(account?.identityPath.path == "/Users/someone/.claude.json")
        #expect(account?.credentialPath.path == "/Users/someone/.claude/.credentials.json")
        #expect(account?.isDefault == true)
    }

    @Test func aSecondClaudeHomeKeepsIdentityInsideItself() {
        let account = AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountID("work"),
            directory: URL(filePath: "/support/accounts/claudeCode/work"),
            isDefault: false
        )
        #expect(account.identityPath.path == "/support/accounts/claudeCode/work/.claude.json")
        #expect(account.credentialPath.path == "/support/accounts/claudeCode/work/.credentials.json")
    }

    @Test func defaultCodexHomeKeepsBothFilesInsideItself() {
        let account = AgentAccountHome.defaultHome(for: .codex, home: URL(filePath: "/Users/someone"))
        #expect(account?.directory.path == "/Users/someone/.codex")
        #expect(account?.identityPath.path == "/Users/someone/.codex/auth.json")
        #expect(account?.credentialPath.path == "/Users/someone/.codex/auth.json")
    }

    @Test func defaultGrokHomeFollowsTheCodexShape() {
        let account = AgentAccountHome.defaultHome(for: .grok, home: URL(filePath: "/Users/someone"))
        #expect(account?.directory.path == "/Users/someone/.grok")
        #expect(account?.identityPath.path == "/Users/someone/.grok/auth.json")
        #expect(account?.credentialPath.path == "/Users/someone/.grok/auth.json")
    }

    @Test func defaultIdentifiersDifferPerProviderSoTheyCannotCollide() {
        let home = URL(filePath: "/Users/someone")
        let claude = AgentAccountHome.defaultHome(for: .claudeCode, home: home)
        let codex = AgentAccountHome.defaultHome(for: .codex, home: home)
        #expect(claude?.id.rawValue == "default.claudeCode")
        #expect(codex?.id.rawValue == "default.codex")
    }

    @Test func providersWithoutAMeasuredConfigDirectoryHaveNoDefaultHome() {
        #expect(AgentAccountHome.defaultHome(for: .cursor, home: URL(filePath: "/Users/someone")) == nil)
        #expect(AgentAccountHome.defaultHome(for: .openCode, home: URL(filePath: "/Users/someone")) == nil)
    }
}
