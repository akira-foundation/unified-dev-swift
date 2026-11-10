import Foundation
import Testing
@testable import Core

@Suite("Removing an account row while a process holds its folder", .tags(.persistence), .scratchDirectory)
struct AgentAccountRowGateTests {
    private func scratchSupport() -> URL {
        URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
    }

    @Test func anAccountRowIsRefusedAndKeptWhileAProcessHoldsItsFolder() async throws {
        let store = try makeTestStore("row-gate")
        let support = scratchSupport()
        let made = AgentAccountCreation.plan(provider: .claudeCode, label: "Client", existing: [], support: support)
        try AgentAccountCreation.prepareDirectory(of: made.home)
        try await store.add(AgentAccountRow(id: made.id, provider: .claudeCode, directory: made.directory.path, label: "Client"))
        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(), defaults: []
        )
        let row = try #require(
            AgentAccountPanel.make(provider: .claudeCode, standings: standings, codexStorageMode: .file).rows.first
        )
        let holder = ProcessVector(pid: 7, strings: ["X=\(made.directory.path)"])

        await #expect(throws: AgentAccountError.folderInUse(made.directory.path)) {
            try await AgentAccountRemoval.remove(row, support: support, store: store, keychain: .untouched, processes: { [holder] })
        }

        #expect(FileManager.default.fileExists(atPath: made.directory.path))
        #expect(try await store.agentAccounts().map(\.id) == [made.id])
    }

    @Test func anUnfinishedRowIsRefusedWhileAProcessHoldsItsFolder() async throws {
        let store = try makeTestStore("row-gate")
        let support = scratchSupport()
        let orphan = AgentAccountCreation.plan(provider: .codex, label: "Client", existing: [], support: support)
        try AgentAccountCreation.prepareDirectory(of: orphan.home)
        let panel = AgentAccountPanel.make(
            provider: .codex, standings: [], orphans: [orphan.home], codexStorageMode: .file
        )
        let row = try #require(panel.rows.first)
        let holder = ProcessVector(pid: 7, strings: ["X=\(orphan.directory.path)"])

        await #expect(throws: AgentAccountError.folderInUse(orphan.directory.path)) {
            try await AgentAccountRemoval.remove(row, support: support, store: store, keychain: .untouched, processes: { [holder] })
        }

        #expect(FileManager.default.fileExists(atPath: orphan.directory.path))
    }
}
