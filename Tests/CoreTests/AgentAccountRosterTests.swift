import Testing
import Foundation
@testable import Core

@Suite("Agent account roster")
struct AgentAccountRosterTests {
    private let support = URL(filePath: "/support")
    private let user = URL(filePath: "/Users/someone")

    private var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }
    private var defaultCodex: AgentAccountHome { AgentAccountHome.defaultHome(for: .codex, home: user)! }
    private var defaultGrok: AgentAccountHome { AgentAccountHome.defaultHome(for: .grok, home: user)! }

    private var workRow: AgentAccountRow {
        AgentAccountRow(
            id: AgentAccountID("work"),
            provider: .claudeCode,
            directory: AgentAccountHomes.directory(for: AgentAccountID("work"), provider: .claudeCode, support: support).path,
            label: "Work"
        )
    }

    private let readsNothing: @Sendable (AgentAccountHome) -> (identity: Data?, credential: Data?) = { _ in (nil, nil) }
    private let claimsNothing: @Sendable (AgentAccountHome) async -> AgentAccountLiveness.CliReport = { _ in .unanswered }

    private func claudeIdentity(email: String) -> Data {
        Data(#"{"oauthAccount":{"emailAddress":"\#(email)"}}"#.utf8)
    }

    @Test func theRosterIsTheDefaultDirectoryPlusTheOnesTheAppMade() async {
        let standings = await AgentAccountRoster.standings(
            rows: [workRow], defaults: [defaultClaude], read: readsNothing,
            codexStorageMode: .file, report: claimsNothing
        )
        #expect(standings.map(\.home.id) == [defaultClaude.id, workRow.id])
    }

    @Test func aRowBecomesAHomeThatIsNotTheDefault() async {
        let standings = await AgentAccountRoster.standings(
            rows: [workRow], defaults: [], read: readsNothing, codexStorageMode: .file, report: claimsNothing
        )
        #expect(standings[0].home.directory.path == workRow.directory)
        #expect(standings[0].home.provider == .claudeCode)
        let isDefault = standings[0].home.isDefault
        #expect(!isDefault)
    }

    @Test func twoAccountsReportingTheSameEmailStayTwoStandings() async {
        let same = claudeIdentity(email: "a@b.c")
        let standings = await AgentAccountRoster.standings(
            rows: [workRow], defaults: [defaultClaude], read: { _ in (same, nil) },
            codexStorageMode: .file, report: claimsNothing
        )
        #expect(standings.count == 2)
        #expect(standings.allSatisfy { $0.identity.email == "a@b.c" })
        #expect(Set(standings.map(\.home.directory)).count == 2)
    }

    @Test func eachStandingIsReadFromItsOwnHome() async {
        let work = workRow
        let standings = await AgentAccountRoster.standings(
            rows: [work], defaults: [defaultClaude],
            read: { home in
                (self.claudeIdentity(email: home.isDefault ? "me@home" : "me@work"), nil)
            },
            codexStorageMode: .file, report: claimsNothing
        )
        #expect(standings.map(\.identity.email) == ["me@home", "me@work"])
    }

    @Test func theCliReportIsCarriedAsItWasGivenWithoutBecomingAYesOrNo() async {
        let reports: [AgentAccountID: AgentAccountLiveness.CliReport] = [
            defaultClaude.id: .claimsSession,
            workRow.id: .claimsNoSession,
            defaultCodex.id: .unanswered,
        ]
        let standings = await AgentAccountRoster.standings(
            rows: [workRow], defaults: [defaultClaude, defaultCodex], read: readsNothing,
            codexStorageMode: .file, report: { reports[$0.id] ?? .unanswered }
        )
        #expect(standings.map(\.cliReport) == [.claimsSession, .unanswered, .claimsNoSession])
    }

    @Test func everyHomeIsAskedAndTheOrderSurvivesAnswersArrivingOutOfOrder() async {
        let rows = (0..<6).map {
            AgentAccountRow(id: AgentAccountID("r\($0)"), provider: .claudeCode, directory: "/support/r\($0)")
        }
        let standings = await AgentAccountRoster.standings(
            rows: rows, defaults: [defaultClaude], read: readsNothing, codexStorageMode: .file,
            report: { home in
                let delay = home.id.rawValue == "r0" ? 80 : 1
                try? await Task.sleep(for: .milliseconds(delay))
                return .claimsSession
            }
        )
        #expect(standings.map(\.home.id.rawValue) == ["default.claudeCode", "r0", "r1", "r2", "r3", "r4", "r5"])
        #expect(standings.allSatisfy { $0.cliReport == .claimsSession })
    }

    @Test func codexIsolationIsNotGuaranteedWhenTheStorageModeIsNotFile() async {
        let standings = await AgentAccountRoster.standings(
            rows: [], defaults: [defaultCodex], read: readsNothing, codexStorageMode: .keyring, report: claimsNothing
        )
        #expect(standings[0].isolationIsGuaranteed == false)
        #expect(standings[0].isolationDoubt?.isEmpty == false)
    }

    @Test func codexIsolationIsGuaranteedInFileMode() async {
        let standings = await AgentAccountRoster.standings(
            rows: [], defaults: [defaultCodex], read: readsNothing, codexStorageMode: .file, report: claimsNothing
        )
        #expect(standings[0].isolationIsGuaranteed == true)
        #expect(standings[0].isolationDoubt == nil)
    }

    @Test func claudeIsolationDoesNotDependOnTheCodexStorageMode() async {
        let standings = await AgentAccountRoster.standings(
            rows: [], defaults: [defaultClaude], read: readsNothing, codexStorageMode: .keyring, report: claimsNothing
        )
        #expect(standings[0].isolationIsGuaranteed == true)
        #expect(standings[0].isolationDoubt == nil)
    }

    @Test func grokIsolationIsNeverGuaranteedBecauseItWasNeverMeasured() async {
        let standings = await AgentAccountRoster.standings(
            rows: [], defaults: [defaultGrok], read: readsNothing, codexStorageMode: .file, report: claimsNothing
        )
        #expect(standings[0].isolationIsGuaranteed == false)
        #expect(standings[0].isolationDoubt?.contains("GROK_HOME") == true)
    }

    @Test func aRowWhoseDirectoryIsGoneIsStillListedWithAnEmptyIdentity() async {
        let standings = await AgentAccountRoster.standings(
            rows: [workRow], defaults: [], read: readsNothing, codexStorageMode: .file, report: claimsNothing
        )
        #expect(standings.count == 1)
        #expect(standings[0].identity == AgentAccountIdentity())
    }

    @Test(arguments: [
        [:],
        ["CLAUDE_CONFIG_DIR": "/elsewhere/claude"],
        ["CODEX_HOME": "/elsewhere/codex"],
        ["CLAUDE_CONFIG_DIR": "/elsewhere/claude", "CODEX_HOME": "/elsewhere/codex"],
        ["CLAUDE_CONFIG_DIR": "", "CODEX_HOME": ""],
    ] as [[String: String]])
    func everyDirectoryTheSpendIndexerReadsIsOnTheRoster(environment: [String: String]) async {
        let indexed = TranscriptSources.sources(home: user, environment: environment)
        let standings = await AgentAccountRoster.standings(
            rows: [workRow],
            defaults: SpendAccounts.defaultHomes(home: user, environment: environment),
            read: readsNothing, codexStorageMode: .file, report: claimsNothing
        )
        let listed = Set(standings.map { $0.home.directory.standardizedFileURL.path })
        let missing = indexed.filter { !listed.contains($0.home.standardizedFileURL.path) }
        #expect(!indexed.isEmpty)
        #expect(missing.isEmpty)
    }

    @Test func theDefaultHomeThatIgnoresTheEnvironmentIsNotWhatTheIndexerReads() {
        let environment = ["CLAUDE_CONFIG_DIR": "/elsewhere/claude"]
        let indexed = TranscriptSources.sources(home: user, environment: environment)
        #expect(indexed.first { $0.provider == .claudeCode }?.home.path == "/elsewhere/claude")
        #expect(defaultClaude.directory.path != "/elsewhere/claude")
    }

    @Test func anAbsentConfigFileReadsAsFileModeBecauseThatIsWhatWasMeasured() {
        #expect(CodexAuthStorageMode.read(configTOML: nil) == .file)
    }

    @Test func aConfigWithoutTheKeyReadsAsFileMode() {
        let toml = "model = \"gpt\"\n[features]\njs_repl = false\n"
        #expect(CodexAuthStorageMode.read(configTOML: Data(toml.utf8)) == .file)
    }

    @Test func theSecretAuthStorageFeatureReadsAsKeyring() {
        let toml = "[features]\njs_repl = false\nsecret_auth_storage = true\n"
        #expect(CodexAuthStorageMode.read(configTOML: Data(toml.utf8)) == .keyring)
    }

    @Test func theSecretAuthStorageFeatureSwitchedOffReadsAsFileMode() {
        let toml = "[features]\nsecret_auth_storage = false # off\n"
        #expect(CodexAuthStorageMode.read(configTOML: Data(toml.utf8)) == .file)
    }

    @Test func theFeatureKeyOutsideTheFeaturesTableIsNotTheFeature() {
        let toml = "[other]\nsecret_auth_storage = true\n"
        #expect(CodexAuthStorageMode.read(configTOML: Data(toml.utf8)) == .file)
    }

    @Test func theDottedFormOfTheFeatureKeyReadsAsKeyring() {
        let toml = "features.secret_auth_storage = true\n"
        #expect(CodexAuthStorageMode.read(configTOML: Data(toml.utf8)) == .keyring)
    }

    @Test(arguments: [("file", CodexAuthStorageMode.file), ("keyring", .keyring), ("auto", .keyring)])
    func theCredentialsStoreKeyIsHonoured(value: String, expected: CodexAuthStorageMode) {
        let toml = "cli_auth_credentials_store = \"\(value)\"\n[features]\njs_repl = false\n"
        #expect(CodexAuthStorageMode.read(configTOML: Data(toml.utf8)) == expected)
    }

    @Test func aCredentialsStoreValueNobodyKnowsDoesNotGuaranteeFileMode() {
        let toml = "cli_auth_credentials_store = \"vault\"\n"
        #expect(CodexAuthStorageMode.read(configTOML: Data(toml.utf8)) == .keyring)
    }

    @Test func aConfigThatIsNotTextReadsAsFileMode() {
        #expect(CodexAuthStorageMode.read(configTOML: Data([0xFF, 0xFE, 0x00])) == .file)
    }
}
