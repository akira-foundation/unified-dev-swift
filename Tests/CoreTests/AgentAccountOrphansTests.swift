import Testing
import Foundation
@testable import Core

@Suite("Agent account orphans")
struct AgentAccountOrphansTests {
    private let support = URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)

    private func candidate(_ name: String, _ provider: AgentKind = .claudeCode) -> AgentAccountOrphans.Candidate {
        AgentAccountOrphans.Candidate(
            provider: provider, name: name,
            directory: AgentAccountHomes.directory(for: AgentAccountID(name), provider: provider, support: support)
        )
    }

    private func row(_ name: String, _ provider: AgentKind = .claudeCode) -> AgentAccountRow {
        AgentAccountRow(
            id: AgentAccountID(name), provider: provider,
            directory: AgentAccountHomes.directory(for: AgentAccountID(name), provider: provider, support: support).path
        )
    }

    @Test func aFolderWithoutARowIsAnOrphan() {
        let found = AgentAccountOrphans.orphans(among: [candidate("kept"), candidate("lost")], rows: [row("kept")], defaults: [])

        #expect(found.map(\.id) == [AgentAccountID("lost")])
        #expect(found.allSatisfy { !$0.isDefault })
    }

    @Test func aRowOfAnotherAgentWithTheSameIdentifierDoesNotAdoptTheFolder() {
        let found = AgentAccountOrphans.orphans(
            among: [candidate("client", .codex)], rows: [row("client", .claudeCode)], defaults: []
        )

        #expect(found.map(\.provider) == [.codex])
    }

    @Test func aDefaultHomeIsNeverAnOrphan() {
        let standard = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountHome.defaultID(for: .claudeCode),
            directory: candidate("claude").directory, isDefault: true
        )

        #expect(AgentAccountOrphans.orphans(among: [candidate("claude")], rows: [], defaults: [standard]).isEmpty)
    }

    @Test func theFolderOfASignInInProgressIsNotAnOrphan() {
        let found = AgentAccountOrphans.orphans(
            among: [candidate("busy"), candidate("lost")], rows: [], defaults: [], excluding: [candidate("busy").directory]
        )

        #expect(found.map(\.id) == [AgentAccountID("lost")])
    }

    @Test func theFoldersOnDiskAreFoundPerAgentAndFilesAreIgnored() throws {
        for provider in [AgentKind.claudeCode, .codex] {
            try FileManager.default.createDirectory(
                at: candidate("left", provider).directory, withIntermediateDirectories: true
            )
        }
        try Data().write(to: AgentAccountHomes.root(support: support).appending(path: "claudeCode/stray.txt"))

        let found = AgentAccountOrphans.find(support: support, rows: [row("left", .codex)], defaults: [])

        #expect(found.map(\.provider) == [.claudeCode])
        #expect(found.map(\.id) == [AgentAccountID("left")])
    }

    @Test func withoutAnAccountsRootThereAreNoOrphans() {
        #expect(AgentAccountOrphans.find(support: support, rows: [], defaults: []).isEmpty)
    }
}
