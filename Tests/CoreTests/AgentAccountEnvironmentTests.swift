import Testing
import Foundation
@testable import Core

@Suite("Agent account environment")
struct AgentAccountEnvironmentTests {
    private let defaultClaude = AgentAccountHome.defaultHome(
        for: .claudeCode, home: URL(filePath: "/Users/someone")
    )!
    private let workClaude = AgentAccountHome(
        provider: .claudeCode,
        id: AgentAccountID("work"),
        directory: URL(filePath: "/support/AgentAccounts/claudeCode/work", directoryHint: .isDirectory),
        isDefault: false
    )
    private let workCodex = AgentAccountHome(
        provider: .codex,
        id: AgentAccountID("work"),
        directory: URL(filePath: "/support/AgentAccounts/codex/work", directoryHint: .isDirectory),
        isDefault: false
    )

    private static let measured: Set<String> = [
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "ANTHROPIC_BASE_URL",
        "CLAUDE_CODE_USER_EMAIL",
        "CLAUDE_CODE_ACCOUNT_UUID",
        "CLAUDE_CODE_ORGANIZATION_UUID",
        "CLAUDECODE",
        "CLAUDE_CODE_ENTRYPOINT",
        "CLAUDE_CODE_SDK_HAS_HOST_AUTH_REFRESH",
        "CLAUDE_CODE_SDK_HAS_OAUTH_REFRESH",
        "CLAUDE_CODE_SESSION_ACCESS_TOKEN",
        "CLAUDE_CODE_HOST_AUTH_ENV_VAR",
        "CLAUDE_CODE_HOST_CREDS_FILE",
        "CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST",
        "CLAUDE_CODE_MESSAGING_SOCKET",
        "CLAUDE_CODE_MESSAGING_TOKEN",
        "CLAUDE_CODE_EXECPATH",
    ]

    @Test func everyInheritedCredentialAndHostAuthVariableIsStripped() {
        var dirty = Dictionary(uniqueKeysWithValues: Self.measured.map { ($0, "x") })
        dirty["PATH"] = "/usr/bin"
        let clean = AgentAccountEnvironment.apply(workClaude, to: dirty)
        for key in Self.measured { #expect(clean[key] == nil, "\(key) survived") }
        #expect(clean["PATH"] == "/usr/bin")
    }

    @Test func theStrippedSetIsExactlyTheSeventeenVariablesThatWereMeasured() {
        #expect(AgentAccountEnvironment.stripped == Self.measured)
    }

    @Test func aClaudeAccountIsPointedAtByItsConfigDirectory() {
        let clean = AgentAccountEnvironment.apply(workClaude, to: [:])
        #expect(clean["CLAUDE_CONFIG_DIR"] == workClaude.directory.path)
        #expect(clean["CODEX_HOME"] == nil)
    }

    @Test func aCodexAccountIsPointedAtByItsHome() {
        let clean = AgentAccountEnvironment.apply(workCodex, to: [:])
        #expect(clean["CODEX_HOME"] == workCodex.directory.path)
        #expect(clean["CLAUDE_CONFIG_DIR"] == nil)
    }

    @Test func theDefaultAccountSetsNoDirectoryVariableAndStillStrips() {
        let clean = AgentAccountEnvironment.apply(defaultClaude, to: ["ANTHROPIC_API_KEY": "x"])
        #expect(clean["CLAUDE_CONFIG_DIR"] == nil)
        #expect(clean["ANTHROPIC_API_KEY"] == nil)
    }

    @Test func noAccountStillStripsTheInheritedVariables() {
        let clean = AgentAccountEnvironment.apply(
            nil, to: ["ANTHROPIC_API_KEY": "x", "CLAUDECODE": "1", "PATH": "/usr/bin"]
        )
        #expect(clean["ANTHROPIC_API_KEY"] == nil)
        #expect(clean["CLAUDECODE"] == nil)
        #expect(clean["PATH"] == "/usr/bin")
    }

    @Test func aStaleDirectoryVariableInTheInheritedEnvironmentIsReplacedNotKept() {
        let clean = AgentAccountEnvironment.apply(workClaude, to: ["CLAUDE_CONFIG_DIR": "/somewhere/else"])
        #expect(clean["CLAUDE_CONFIG_DIR"] == workClaude.directory.path)
    }

    @Test func variablesThatAreNotCredentialsPassThroughUntouched() {
        let inherited = ["HOME": "/Users/someone", "PATH": "/usr/bin", "LANG": "en_GB.UTF-8"]
        #expect(AgentAccountEnvironment.apply(workClaude, to: inherited).filter { $0.key != "CLAUDE_CONFIG_DIR" } == inherited)
    }
}
