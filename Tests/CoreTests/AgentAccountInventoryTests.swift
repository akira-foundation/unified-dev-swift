import Testing
import Foundation
import Synchronization
@testable import Core

private final class AskedLog: Sendable {
    private let ids = Mutex<[AgentAccountID]>([])

    var all: [AgentAccountID] { ids.withLock { $0 } }

    var report: @Sendable (AgentAccountHome) async -> AgentAccountLiveness.CliReport {
        { home in
            self.ids.withLock { $0.append(home.id) }
            return .claimsSession
        }
    }
}

@Suite("Agent account inventory", .scratchDirectory)
struct AgentAccountInventoryTests {
    private func row(_ name: String, at directory: String, provider: AgentKind = .claudeCode) -> AgentAccountRow {
        AgentAccountRow(id: AgentAccountID(name), provider: provider, directory: directory, label: name)
    }

    private func makeDirectory(_ name: String) throws -> String {
        let path = TestScratch.unique(name)
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    @Test func aDirectoryThatIsThereIsReportedAsExistingAndAskedAbout() async throws {
        let present = row("present", at: try makeDirectory("present"))
        let probe = AskedLog()

        let standings = await AgentAccountInventory.standings(rows: [present], defaults: [], report: probe.report)

        #expect(standings.map(\.directoryExists) == [true])
        #expect(standings.map(\.cliReport) == [.claimsSession])
        #expect(probe.all == [present.id])
    }

    @Test func aDirectoryThatIsGoneIsNeverAskedAboutAndIsNeverCreated() async {
        let missing = TestScratch.unique("missing")
        let gone = row("gone", at: missing)
        let probe = AskedLog()

        let standings = await AgentAccountInventory.standings(rows: [gone], defaults: [], report: probe.report)

        #expect(standings.map(\.directoryExists) == [false])
        #expect(standings.map(\.cliReport) == [.unanswered])
        #expect(probe.all.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: missing))
    }

    @Test func aFileWhereADirectoryShouldBeDoesNotCountAsADirectory() async throws {
        let file = TestScratch.unique("not-a-directory")
        try Data().write(to: URL(filePath: file))
        let probe = AskedLog()

        let standings = await AgentAccountInventory.standings(
            rows: [row("file", at: file)], defaults: [], report: probe.report
        )

        #expect(standings.map(\.directoryExists) == [false])
        #expect(probe.all.isEmpty)
    }

    @Test func listingWithoutAskingNeverAsksAndKeepsTheExistenceVerdict() async throws {
        let present = row("present", at: try makeDirectory("present"))
        let gone = row("gone", at: TestScratch.unique("missing"))

        let standings = await AgentAccountInventory.standingsWithoutAsking(rows: [present, gone], defaults: [])

        #expect(standings.map(\.cliReport) == [.unanswered, .unanswered])
        #expect(standings.map(\.directoryExists) == [true, false])
    }

    @Test func identityIsReadFromTheAccountsOwnFiles() async throws {
        let directory = try makeDirectory("signed-in")
        try Data(#"{"oauthAccount":{"emailAddress":"work@client.com"}}"#.utf8)
            .write(to: URL(filePath: directory).appending(path: ".claude.json"))

        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: [row("work", at: directory)], defaults: []
        )

        #expect(standings.first?.identity.email == "work@client.com")
    }

    @Test func theCodexStorageModeComesFromTheDefaultCodexHome() async throws {
        let codexHome = try makeDirectory("codex-home")
        try Data("cli_auth_credentials_store = \"keyring\"\n".utf8)
            .write(to: URL(filePath: codexHome).appending(path: "config.toml"))
        let home = AgentAccountHome(
            provider: .codex, id: AgentAccountHome.defaultID(for: .codex),
            directory: URL(filePath: codexHome, directoryHint: .isDirectory), isDefault: true
        )

        let standings = await AgentAccountInventory.standingsWithoutAsking(rows: [], defaults: [home])

        #expect(standings.first?.isolationIsGuaranteed == false)
    }
}
