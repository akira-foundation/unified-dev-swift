import Testing
import Foundation
@testable import Core

@Suite("Agent account creation")
struct AgentAccountCreationTests {
    private let support = URL(filePath: "/support", directoryHint: .isDirectory)

    private func plan(
        _ provider: AgentKind = .claudeCode,
        label: String = "Client",
        existing: [AgentAccountID] = [],
        discriminant: String = AgentAccountCreation.freshDiscriminant()
    ) -> AgentAccountCreation {
        AgentAccountCreation.plan(
            provider: provider, label: label, existing: existing, support: support, discriminant: discriminant
        )
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
        #expect(made.home.isDefault == false)
        #expect(made.home.directory == made.directory)
    }

    @Test func anAccountMadeAgainUnderTheSameLabelNeverGetsTheIdentifierOfTheFirst() {
        let first = plan(label: "Client")
        let again = plan(label: "Client")
        #expect(first.id != again.id)
        #expect(first.directory != again.directory)
    }

    @Test func theIdentifierIsTheLabelFollowedByTheDiscriminant() {
        #expect(plan(label: "Client", discriminant: "a1b2c3d4").id == AgentAccountID("client-a1b2c3d4"))
    }

    @Test func aFreshDiscriminantIsEightHexCharactersAndDiffersEachTime() {
        let first = AgentAccountCreation.freshDiscriminant()
        let second = AgentAccountCreation.freshDiscriminant()
        #expect(first.count == 8)
        #expect(first.allSatisfy { $0.isHexDigit })
        #expect(first != second)
    }

    @Test func anIdentifierNeverCollidesWithOneThatExists() {
        let first = plan(discriminant: "same")
        let second = plan(existing: [first.id], discriminant: "same")
        let third = plan(existing: [first.id, second.id], discriminant: "same")
        #expect(second.id != first.id)
        #expect(second.directory != first.directory)
        #expect(third.id != first.id && third.id != second.id)
    }

    @Test func anIdentifierIgnoresTheCaseOfOneThatExists() {
        #expect(plan(existing: [AgentAccountID("Client-Same")], discriminant: "same").id != AgentAccountID("client-same"))
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

    @Test func aSuffixedIdentifierStaysWithinTheLengthLimit() {
        let long = String(repeating: "x", count: 200)
        let first = plan(label: long, discriminant: "same")
        let second = plan(label: long, existing: [first.id], discriminant: "same")
        let taken = [first.id, second.id] + (3...9).map { AgentAccountID(String(first.id.rawValue.prefix(38)) + "-\($0)") }
        let tenth = plan(label: long, existing: taken, discriminant: "same")
        for made in [first, second, tenth] { #expect(made.id.rawValue.count <= 40) }
        #expect(second.id != first.id)
        #expect(tenth.id != second.id)
    }

    @Test func aLabelBecomesAReadableIdentifier() {
        #expect(plan(label: "Cliente José", discriminant: "a1b2c3d4").id == AgentAccountID("cliente-jose-a1b2c3d4"))
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

    @Test func aLoginTheCliDidNotAnswerForStillSettlesWhenItLeftAnIdentity() throws {
        let standing = try #require(settle(plan(), identity: completedLoginIdentity, credential: nil, report: .unanswered))
        #expect(standing.cliReport == .unanswered)
        #expect(standing.identity.email == "a@b.c")
    }

    @Test(arguments: AgentKind.allCases)
    func aLoginTheCliDidNotAnswerForAndLeftNothingSettlesToNothing(provider: AgentKind) {
        #expect(settle(plan(provider), identity: nil, credential: nil, report: .unanswered) == nil)
    }

    @Test func aSettledStandingCarriesTheDoubtAboutIsolationOfItsBackend() throws {
        let claude = try #require(settle(plan(), report: .claimsSession))
        let grok = try #require(settle(plan(.grok), report: .claimsSession))
        let keyring = try #require(settle(plan(.codex), report: .claimsSession, codexStorageMode: .keyring))
        let file = try #require(settle(plan(.codex), report: .claimsSession, codexStorageMode: .file))
        #expect(claude.isolationDoubt == nil)
        #expect(file.isolationDoubt == nil)
        #expect(grok.isolationDoubt != nil)
        #expect(keyring.isolationDoubt != nil)
    }

    @Test func aSettledStandingIsNeverTheDefaultAccount() throws {
        let standing = try #require(settle(plan(), report: .claimsSession))
        #expect(standing.home.isDefault == false)
    }

    @Test func theCopiedSignInCommandRunsInItsOwnShellAndNamesTheExecutableLast() {
        let made = plan()
        let command = AgentAccountCreation.signInCommand(
            executable: "/usr/local/bin/claude", provider: .claudeCode, account: made.home, directory: "/tmp"
        )
        #expect(command.contains("'CLAUDE_CONFIG_DIR=\(made.directory.path)'"))
        #expect(command.hasPrefix("(ud_unsets=$("))
        #expect(command.hasSuffix("'/usr/local/bin/claude' 'auth' 'login')"))
    }

    @Test(
        "the copied sign-in command drops every inherited credential in a real shell",
        .tags(.subprocess),
        arguments: SignInShell.all, SignInShell.cases
    )
    func theCopiedSignInCommandIsMeasuredInARealShell(
        shell: String, signIn: SignInShell.Case
    ) async throws {
        let opening = signIn.opening
        let root = URL(filePath: TestScratch.unique("sign-in"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let account = signIn.ofItsOwnAccount
            ? AgentAccountCreation.plan(provider: .claudeCode, label: "Client", existing: [], support: root).home
            : nil
        let fake = root.appending(path: "claude")
        try Data("#!/bin/sh\necho \"\(SignInShell.probe)\"\n".utf8).write(to: fake)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fake.path)
        let command = AgentAccountCreation.signInCommand(
            executable: fake.path, provider: .claudeCode, account: account, directory: root.path
        )

        let result = try await Shell.run(
            shell,
            ["-c", opening + SignInShell.separatorCapture + command + SignInShell.trailer],
            env: SignInShell.dirty
        )

        #expect(result.ok, "\(shell) exited \(result.status): \(result.stderr)")
        let reported = SignInShell.reading(of: result.trimmed)
        for name in SignInShell.credentials {
            #expect(reported[name] == "unset", "\(name) survived \(shell) after \(opening)")
        }
        for (name, inherited) in SignInShell.inheritedDirectories where name != "CLAUDE_CONFIG_DIR" {
            #expect(reported[name] == inherited, "\(name) was dropped by \(shell) after \(opening)")
        }
        #expect(reported["CLAUDE_CONFIG_DIR"] == (account?.directory.path ?? "/somewhere/else"))
        #expect(reported["PATH"]?.contains("/usr/bin") == true)
        #expect(reported["ifs"] == "intact", "\(shell) was left with another separator after \(opening)")
        #expect(reported["pwd"] != root.path, "\(shell) was left in the account's directory after \(opening)")
    }

    @Test(
        "the copied sign-in command stops instead of launching the agent it cannot clean for",
        .tags(.subprocess),
        arguments: SignInShell.all
    )
    func theCopiedSignInCommandFailsClosed(shell: String) async throws {
        let root = URL(filePath: TestScratch.unique("sign-in-closed"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fake = root.appending(path: "claude")
        try Data("#!/bin/sh\necho \"\(SignInShell.probe)\"\n".utf8).write(to: fake)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fake.path)
        let command = AgentAccountCreation.signInCommand(
            executable: fake.path, provider: .claudeCode, account: nil, directory: root.path
        )
        let broken = command.replacingOccurrences(
            of: "/usr/bin/awk", with: root.appending(path: "no-such-awk").path
        )

        let result = try await Shell.run(shell, ["-c", broken], env: SignInShell.dirty)

        #expect(!result.ok, "\(shell) carried on after the listing failed")
        #expect(!result.stdout.contains("CLAUDECODE="), "\(shell) launched the agent anyway")
        #expect(result.stderr.contains(AgentAccountEnvironment.listingFailure))
    }

    @Test(
        """
        a shell name that holds a command is never listed, so the eval cannot run it, \
        and widening what the listing emits is what breaks this
        """,
        .tags(.subprocess, .security),
        arguments: SignInShell.all
    )
    func theCopiedSignInCommandCannotBeMadeToRunANameItWasGiven(shell: String) async throws {
        let root = URL(filePath: TestScratch.unique("sign-in-eval"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fake = root.appending(path: "claude")
        try Data("#!/bin/sh\necho \"\(SignInShell.probe)\"\n".utf8).write(to: fake)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fake.path)
        let marker = root.appending(path: "ran")
        var dirty = SignInShell.dirty
        dirty["CLAUDE_EVIL;/usr/bin/touch \(marker.path)"] = "x"
        let command = AgentAccountCreation.signInCommand(
            executable: fake.path, provider: .claudeCode, account: nil, directory: root.path
        )

        let result = try await Shell.run(shell, ["-c", command], env: dirty)

        #expect(result.ok, "\(shell) exited \(result.status): \(result.stderr)")
        #expect(
            !FileManager.default.fileExists(atPath: marker.path),
            "\(shell) ran the name it was given"
        )
        #expect(SignInShell.reading(of: result.trimmed)["CLAUDECODE"] == "unset")
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
