import Testing
import Foundation
@testable import Core

@Suite("Agent account removal", .tags(.persistence), .scratchDirectory)
struct AgentAccountRemovalTests {
    private func scratchSupport() -> URL {
        URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
    }

    private func created(
        _ label: String, in store: Store, support: URL, provider: AgentKind = .claudeCode
    ) async throws -> AgentAccountHome {
        let made = AgentAccountCreation.plan(provider: provider, label: label, existing: [], support: support)
        try AgentAccountCreation.prepareDirectory(of: made.home)
        try Data("session".utf8).write(to: made.directory.appending(path: "transcript.jsonl"))
        try await store.add(AgentAccountRow(id: made.id, provider: provider, directory: made.directory.path, label: label))
        return made.home
    }

    @Test func removingAnAccountDeletesItsFolderAndItsRow() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let home = try await created("Client", in: store, support: support)

        try await AgentAccountRemoval.remove(home, support: support, store: store)

        #expect(!FileManager.default.fileExists(atPath: home.directory.path))
        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test func removingAnAccountLeavesTheFolderOfAnother() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let gone = try await created("Gone", in: store, support: support)
        let kept = try await created("Kept", in: store, support: support)

        try await AgentAccountRemoval.remove(gone, support: support, store: store)

        #expect(FileManager.default.fileExists(atPath: kept.directory.appending(path: "transcript.jsonl").path))
        #expect(try await store.agentAccounts().map(\.id) == [kept.id])
    }

    @Test func removingAnAccountWhoseFolderIsAlreadyGoneStillForgetsIt() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let home = try await created("Client", in: store, support: support)
        try FileManager.default.removeItem(at: home.directory)

        try await AgentAccountRemoval.remove(home, support: support, store: store)

        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test func aFolderOutsideTheAccountsRootIsForgottenButNeverDeleted() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let elsewhere = URL(filePath: TestScratch.unique("not-ours"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let home = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID("odd"), directory: elsewhere, isDefault: false
        )
        try await store.add(AgentAccountRow(id: home.id, provider: .claudeCode, directory: elsewhere.path))

        try await AgentAccountRemoval.remove(home, support: support, store: store)

        #expect(FileManager.default.fileExists(atPath: elsewhere.path))
        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test func theAccountsRootItselfIsNeverTheFolderOfAnAccount() {
        let support = scratchSupport()
        let root = AgentAccountHomes.root(support: support)
        let home = AgentAccountHome(provider: .claudeCode, id: AgentAccountID("x"), directory: root, isDefault: false)

        #expect(AgentAccountRemoval.directory(of: home, support: support) == nil)
    }

    @Test(arguments: AgentKind.allCases)
    func aDefaultAccountIsNeverRemovedAndItsFolderIsNeverTouched(provider: AgentKind) async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let folder = support.appending(path: provider.rawValue, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let home = AgentAccountHome(
            provider: provider, id: AgentAccountHome.defaultID(for: provider), directory: folder, isDefault: true
        )
        try await store.add(AgentAccountRow(id: home.id, provider: provider, directory: folder.path, isDefault: true))

        await #expect(throws: AgentAccountError.isDefault(home.id)) {
            try await AgentAccountRemoval.remove(home, support: support, store: store)
        }

        #expect(FileManager.default.fileExists(atPath: folder.path))
        #expect(try await store.agentAccounts().map(\.id) == [home.id])
    }

    @Test func theWarningSaysWhatIsDeletedAndWhatIsLeftBehind() {
        let warning = AgentAccountRemoval.warning(forAccountNamed: "me@client.com", folderExists: true)

        #expect(warning.title == "Remove me@client.com?")
        #expect(warning.message.contains("deletes the account's folder"))
        #expect(warning.message.contains("saved sign-in"))
        #expect(warning.message.contains("conversation transcripts"))
        #expect(warning.message.contains("goes back to the default account"))
        #expect(warning.message.contains("entry this account left in your keychain"))
        #expect(warning.message.contains("Keychain Access"))
    }

    @Test func theWarningOfAnAccountWhoseFolderIsGoneDoesNotPromiseADeletion() {
        let warning = AgentAccountRemoval.warning(forAccountNamed: "work", folderExists: false)

        #expect(!warning.message.contains("deletes the account's folder"))
        #expect(warning.message.contains("already gone"))
        #expect(warning.message.contains("Keychain Access"))
    }
}
