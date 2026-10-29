import Testing
import Foundation
@testable import Core

@Suite("Agent account creation")
struct AgentAccountCreationTests {
    private let support = URL(filePath: "/support", directoryHint: .isDirectory)

    private func plan(
        _ provider: AgentKind = .claudeCode,
        label: String = "Client",
        existing: [AgentAccountID] = []
    ) -> AgentAccountCreation {
        AgentAccountCreation.plan(provider: provider, label: label, existing: existing, support: support)
    }

    private func settle(
        _ plan: AgentAccountCreation,
        identity: Data? = nil,
        credential: Data? = nil,
        report: AgentAccountLiveness.CliReport,
        codexStorageMode: CodexAuthStorageMode = .file
    ) -> AgentAccountStanding? {
        AgentAccountCreation.settled(
            plan, identity: identity, credential: credential, report: report, codexStorageMode: codexStorageMode
        )
    }

    private let interruptedLoginIdentity = Data(
        #"{"oauthAccount":{"accountUuid":"u","emailAddress":"a@b.c","organizationUuid":"o"}}"#.utf8
    )

    private let completedLoginIdentity = Data(
        #"{"oauthAccount":{"emailAddress":"a@b.c","organizationName":"Client Ltd"}}"#.utf8
    )

    @Test func aNewAccountGetsItsOwnDirectoryUnderTheAppSupportRoot() {
        let made = plan()
        #expect(made.directory.path.hasPrefix(support.appending(path: "AgentAccounts/claudeCode").path))
        #expect(made.environment["CLAUDE_CONFIG_DIR"] == made.directory.path)
        #expect(made.loginArguments == ["auth", "login"])
    }

    @Test func theLoginEnvironmentCarriesNoInheritedCredential() {
        let made = plan()
        for key in AgentAccountEnvironment.stripped { #expect(made.environment[key] == nil) }
    }

    @Test func anIdentifierNeverCollidesWithOneThatExists() {
        let first = plan()
        let second = plan(existing: [first.id])
        let third = plan(existing: [first.id, second.id])
        #expect(second.id != first.id)
        #expect(second.directory != first.directory)
        #expect(third.id != first.id && third.id != second.id)
    }

    @Test func anIdentifierIgnoresTheCaseOfOneThatExists() {
        #expect(plan(existing: [AgentAccountID("Client")]).id != AgentAccountID("client"))
    }

    @Test func anIdentifierNeverTakesTheShapeOfADefaultAccount() {
        for provider in AgentKind.allCases {
            let made = plan(provider, label: AgentAccountHome.defaultID(for: provider).rawValue)
            #expect(made.id != AgentAccountHome.defaultID(for: provider))
            #expect(!made.id.rawValue.contains("."))
        }
    }

    @Test(arguments: ["../../etc", "  ", "Cliente José", "a/b\\c", "", "...", String(repeating: "x", count: 200)])
    func aLabelNeverEscapesTheAccountsRoot(label: String) {
        let made = plan(label: label)
        let root = AgentAccountHomes.root(support: support).appending(path: "claudeCode").path
        #expect(made.directory.deletingLastPathComponent().path == root)
        #expect(made.id.rawValue.count <= 40)
        #expect(!made.id.rawValue.isEmpty)
    }

    @Test func aLabelBecomesAReadableIdentifier() {
        #expect(plan(label: "Cliente José").id == AgentAccountID("cliente-jose"))
    }

    @Test func aLoginThatTheCliSaysHasNoSessionSettlesToNothing() {
        let standing = settle(plan(), identity: interruptedLoginIdentity, credential: nil, report: .claimsNoSession)
        #expect(standing == nil)
    }

    @Test func aLoginThatTheCliSaysHasASessionSettlesToAStandingNamedByItsIdentity() {
        let made = plan()
        let standing = settle(made, identity: completedLoginIdentity, credential: nil, report: .claimsSession)
        #expect(standing?.identity.email == "a@b.c")
        #expect(standing?.cliReport == .claimsSession)
        #expect(standing?.home == made.home)
    }

    @Test func aLoginTheCliDidNotAnswerForStillSettlesToAStanding() {
        let standing = settle(plan(), identity: completedLoginIdentity, credential: nil, report: .unanswered)
        #expect(standing?.cliReport == .unanswered)
        #expect(standing?.identity.email == "a@b.c")
    }

    @Test func aSettledStandingCarriesTheDoubtAboutIsolationOfItsBackend() {
        let claude = settle(plan(), report: .claimsSession)
        let grok = settle(plan(.grok), report: .claimsSession)
        let keyring = settle(plan(.codex), report: .claimsSession, codexStorageMode: .keyring)
        #expect(claude?.isolationDoubt == nil)
        #expect(grok?.isolationDoubt != nil)
        #expect(keyring?.isolationDoubt != nil)
    }

    @Test func aSettledStandingIsNeverTheDefaultAccount() {
        let standing = settle(plan(), report: .claimsSession)
        #expect(standing?.home.isDefault == false)
    }

    @Test func codexSignsInWithItsOwnArgumentsAndItsOwnVariable() {
        let made = plan(.codex)
        #expect(made.loginArguments == ["login"])
        #expect(made.environment["CODEX_HOME"] == made.directory.path)
        #expect(made.environment["CLAUDE_CONFIG_DIR"] == nil)
    }

    @Test func theCopiedSignInCommandPointsAtTheAccountAndClearsTheHostAuthVariables() {
        let command = AgentAccountCreation.signInCommand(
            executable: "/usr/local/bin/claude", provider: .claudeCode, account: plan().home, directory: "/tmp"
        )
        #expect(command.contains("'CLAUDE_CONFIG_DIR=\(plan().directory.path)'"))
        #expect(command.contains("'-u' 'CLAUDE_CODE_SDK_HAS_HOST_AUTH_REFRESH'"))
        #expect(command.hasSuffix("'/usr/local/bin/claude' 'auth' 'login'"))
    }

    @Test func theCopiedSignInCommandOfTheDefaultAccountIsThePlainOne() {
        let command = AgentAccountCreation.signInCommand(
            executable: "/usr/local/bin/claude", provider: .claudeCode, account: nil, directory: "/tmp"
        )
        #expect(command == "cd '/tmp' && '/usr/local/bin/claude' 'auth' 'login'")
    }

    @Test func preparingTheDirectoryCreatesItPrivately() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "ud-creation-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let made = AgentAccountCreation.plan(provider: .claudeCode, label: "Client", existing: [], support: root)

        try AgentAccountCreation.prepareDirectory(of: made.home)

        let attributes = try FileManager.default.attributesOfItem(atPath: made.directory.path)
        #expect(attributes[.posixPermissions] as? Int == 0o700)
    }
}
