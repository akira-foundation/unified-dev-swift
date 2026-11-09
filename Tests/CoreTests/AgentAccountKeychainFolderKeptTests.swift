import Testing
import Foundation
@testable import Core

private actor DeletedEntryCount {
    private(set) var count = 0

    func note() {
        count += 1
    }
}

@Suite("Agent account keychain when the folder is kept", .tags(.persistence), .scratchDirectory)
struct AgentAccountKeychainFolderKeptTests {
    @Test func aFolderThatBecomesHeldAfterTheForgetKeepsItsEntries() async throws {
        let store = try makeTestStore("keychain-kept")
        let support = URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
        let made = AgentAccountCreation.plan(provider: .claudeCode, label: "Client", existing: [], support: support)
        try AgentAccountCreation.prepareDirectory(of: made.home)
        try await store.add(AgentAccountRow(id: made.id, provider: .claudeCode, directory: made.directory.path, label: "Client"))
        let held = ProcessVector(pid: 7, strings: ["CLAUDE_CONFIG_DIR=\(made.directory.path)"])
        let deleted = DeletedEntryCount()
        let keychain = AgentAccountKeychain { _ in
            await deleted.note()
            return true
        }
        let reads = Reads()

        await #expect(throws: AgentAccountError.forgottenWithFolderKept(made.directory.path)) {
            try await AgentAccountRemoval.remove(made.home, support: support, store: store, keychain: keychain, processes: {
                reads.next() == 0 ? [] : [held]
            })
        }

        #expect(await deleted.count == 0)
    }
}
