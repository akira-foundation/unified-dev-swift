import Testing
import Foundation
@testable import Core

@Suite("Agent account removal", .tags(.persistence), .scratchDirectory)
struct AgentAccountRemovalTests {
    private func scratchSupport() -> URL {
        URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
    }

    private func created(
        _ label: String, in store: Store, support: URL, provider: AgentKind = .claudeCode,
        discriminant: String? = nil
    ) async throws -> AgentAccountHome {
        let made = discriminant.map {
            AgentAccountCreation.plan(provider: provider, label: label, existing: [], support: support, discriminant: $0)
        } ?? AgentAccountCreation.plan(provider: provider, label: label, existing: [], support: support)
        try AgentAccountCreation.prepareDirectory(of: made.home)
        try Data("session".utf8).write(to: made.directory.appending(path: "transcript.jsonl"))
        try await store.add(AgentAccountRow(id: made.id, provider: provider, directory: made.directory.path, label: label))
        return made.home
    }

    @Test func removingAnAccountDeletesItsFolderAndItsRow() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let home = try await created("Client", in: store, support: support)

        try await AgentAccountRemoval.remove(home, support: support, store: store, processes: { [] })

        #expect(!FileManager.default.fileExists(atPath: home.directory.path))
        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test func removingAnAccountLeavesTheFolderOfAnother() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let gone = try await created("Gone", in: store, support: support)
        let kept = try await created("Kept", in: store, support: support)

        try await AgentAccountRemoval.remove(gone, support: support, store: store, processes: { [] })

        #expect(FileManager.default.fileExists(atPath: kept.directory.appending(path: "transcript.jsonl").path))
        #expect(try await store.agentAccounts().map(\.id) == [kept.id])
    }

    @Test func removingAnAccountWhoseFolderIsAlreadyGoneStillForgetsIt() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let home = try await created("Client", in: store, support: support)
        try FileManager.default.removeItem(at: home.directory)

        try await AgentAccountRemoval.remove(home, support: support, store: store, processes: { [] })

        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test func aFolderOutsideTheAccountsRootIsForgottenNeverDeletedAndTheOwnerIsTold() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let elsewhere = URL(filePath: TestScratch.unique("not-ours"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let home = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID("odd"), directory: elsewhere, isDefault: false
        )
        try await store.add(AgentAccountRow(id: home.id, provider: .claudeCode, directory: elsewhere.path))

        await #expect(throws: AgentAccountError.folderLeftAlone(elsewhere.path)) {
            try await AgentAccountRemoval.remove(home, support: support, store: store, processes: { [] })
        }

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
            try await AgentAccountRemoval.remove(home, support: support, store: store, processes: { [] })
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

    private func running(
        under home: AgentAccountHome, in store: Store, provider: AgentKind = .claudeCode
    ) async throws {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "billing", branch: "feature/x", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        try await store.chooseAgentAccount(ChosenAgentAccount(home), forRepo: repo.id)
        var session = Session(workspaceID: workspace.id)
        session.agentKind = provider
        session.apply(.turnStarted)
        try await store.upsert(session)
    }

    @Test func anAccountWithAnAgentRunningUnderItIsRefusedAndNothingIsTouched() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let home = try await created("Client", in: store, support: support)
        try await running(under: home, in: store)

        await #expect(throws: AgentAccountError.inUse(workspaces: ["billing"])) {
            try await AgentAccountRemoval.remove(home, support: support, store: store, processes: { [] })
        }

        #expect(FileManager.default.fileExists(atPath: home.directory.path))
        #expect(try await store.agentAccounts().map(\.id) == [home.id])
    }

    @Test func anAgentOfAnotherProviderOnTheSameIdentifierDoesNotBlockRemoval() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let home = try await created("Client", in: store, support: support)
        try await running(under: home, in: store, provider: .codex)

        try await AgentAccountRemoval.remove(home, support: support, store: store, processes: { [] })

        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test func aForgetTheStoreRefusesLeavesTheFolderAndTheTranscriptsAlone() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let made = AgentAccountCreation.plan(provider: .claudeCode, label: "Odd", existing: [], support: support)
        try AgentAccountCreation.prepareDirectory(of: made.home)
        try Data("session".utf8).write(to: made.directory.appending(path: "transcript.jsonl"))
        try await store.add(AgentAccountRow(
            id: made.id, provider: .claudeCode, directory: made.directory.path, isDefault: true
        ))

        await #expect(throws: AgentAccountError.isDefault(made.id)) {
            try await AgentAccountRemoval.remove(made.home, support: support, store: store, processes: { [] })
        }

        #expect(FileManager.default.fileExists(atPath: made.directory.appending(path: "transcript.jsonl").path))
        #expect(try await store.agentAccounts().map(\.id) == [made.id])
    }

    @Test func aFolderWhoseNameIsNotTheIdentifierIsNeverTheFolderOfThatAccount() {
        let support = scratchSupport()
        let sibling = AgentAccountHomes.directory(for: AgentAccountID("other"), provider: .claudeCode, support: support)
        let home = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID("client"), directory: sibling, isDefault: false
        )
        let empty = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID(""),
            directory: AgentAccountHomes.root(support: support).appending(path: "claudeCode", directoryHint: .isDirectory),
            isDefault: false
        )

        #expect(AgentAccountRemoval.directory(of: home, support: support) == nil)
        #expect(AgentAccountRemoval.directory(of: empty, support: support) == nil)
    }

    @Test func aStoredPathThatIsNotNormalisedStillResolvesToTheExpectedFolder() throws {
        let support = scratchSupport()
        let expected = AgentAccountHomes.directory(for: AgentAccountID("client"), provider: .claudeCode, support: support)
        try FileManager.default.createDirectory(at: expected, withIntermediateDirectories: true)
        let link = URL(filePath: TestScratch.unique("link"))
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: support)
        let viaLink = link.appending(path: "AgentAccounts/claudeCode/../claudeCode/client", directoryHint: .isDirectory)
        let home = AgentAccountHome(provider: .claudeCode, id: AgentAccountID("client"), directory: viaLink, isDefault: false)

        #expect(viaLink.path != expected.path)
        #expect(AgentAccountRemoval.directory(of: home, support: support) != nil)
    }

    @Test func aPathThatEscapesThroughALinkIsNotTheFolderOfThatAccount() throws {
        let support = scratchSupport()
        let outside = URL(filePath: TestScratch.unique("outside"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let provider = AgentAccountHomes.root(support: support).appending(path: "claudeCode", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: provider, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: provider.appending(path: "client"), withDestinationURL: outside
        )
        let home = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID("client"),
            directory: provider.appending(path: "client", directoryHint: .isDirectory), isDefault: false
        )

        #expect(AgentAccountRemoval.directory(of: home, support: support) == nil)
    }

    @Test func anUnfinishedSignInFolderIsDeletedWithoutTouchingTheStore() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let other = try await created(
            "Client", in: store, support: support, provider: .claudeCode, discriminant: "a1b2c3d4"
        )
        let orphan = AgentAccountCreation.plan(
            provider: .codex, label: "Client", existing: [], support: support, discriminant: "a1b2c3d4"
        )
        try AgentAccountCreation.prepareDirectory(of: orphan.home)

        try AgentAccountRemoval.removeUnfinished(orphan.home, support: support, processes: { [] })

        #expect(!orphan.directoryExists)
        #expect(try await store.agentAccounts().map(\.id) == [other.id])
    }

    @Test func theWarningOfAnUnfinishedSignInSaysWhatIsDeletedAndWhatIsLeft() {
        let warning = AgentAccountRemoval.warningForUnfinishedSignIn(named: "client")

        #expect(warning.title == "Remove client?")
        #expect(warning.message.contains("did not finish"))
        #expect(warning.message.contains("Keychain Access"))
    }

    @Test func removingAnUnfinishedSignInRowNeverForgetsTheAccountOfAnotherAgentWithTheSameIdentifier() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let claude = try await created(
            "Client", in: store, support: support, provider: .claudeCode, discriminant: "a1b2c3d4"
        )
        let orphan = AgentAccountCreation.plan(
            provider: .codex, label: "Client", existing: [], support: support, discriminant: "a1b2c3d4"
        )
        #expect(claude.id == orphan.id)
        try AgentAccountCreation.prepareDirectory(of: orphan.home)
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        try await store.chooseAgentAccount(ChosenAgentAccount(claude), forRepo: repo.id)
        let panel = AgentAccountPanel.make(
            provider: .codex, standings: [], orphans: [orphan.home], codexStorageMode: .file
        )
        let row = try #require(panel.rows.first)

        try await AgentAccountRemoval.remove(row, support: support, store: store, processes: { [] })

        #expect(!orphan.directoryExists)
        #expect(FileManager.default.fileExists(atPath: claude.directory.path))
        #expect(try await store.agentAccounts().map(\.id) == [claude.id])
        #expect(try await store.agentAccountChoices().repos[repo.id] == [.claudeCode: claude.id])
    }

    @Test func removingAnAccountRowForgetsItAndDeletesItsFolder() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let home = try await created("Client", in: store, support: support)
        let standings = await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(), defaults: []
        )
        let row = try #require(
            AgentAccountPanel.make(provider: .claudeCode, standings: standings, codexStorageMode: .file).rows.first
        )

        try await AgentAccountRemoval.remove(row, support: support, store: store, processes: { [] })

        #expect(!FileManager.default.fileExists(atPath: home.directory.path))
        #expect(try await store.agentAccounts().isEmpty)
    }

    @Test func eachAgentOfAProjectBlocksTheRemovalOfItsOwnAccount() async throws {
        let store = try makeTestStore("removal")
        let support = scratchSupport()
        let claude = try await created("Client", in: store, support: support, provider: .claudeCode)
        let codex = try await created("Lab", in: store, support: support, provider: .codex)
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "billing", branch: "feature/x", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        try await store.chooseAgentAccount(ChosenAgentAccount(claude), forRepo: repo.id)
        try await store.chooseAgentAccount(ChosenAgentAccount(codex), forRepo: repo.id)
        var codexSession = Session(workspaceID: workspace.id)
        codexSession.agentKind = .codex
        codexSession.apply(.turnStarted)
        try await store.upsert(codexSession)
        let invoices = try await store.upsert(Workspace(
            repoID: repo.id, name: "invoices", branch: "feature/y", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        var claudeSession = Session(workspaceID: invoices.id)
        claudeSession.apply(.turnStarted)
        try await store.upsert(claudeSession)

        #expect(try await AgentAccountUsage.runningWorkspaces(under: codex, store: store, defaults: []) == ["billing"])
        #expect(try await AgentAccountUsage.runningWorkspaces(under: claude, store: store, defaults: []) == ["invoices"])
    }

    @Test func aLinkToTheFolderOfAnotherAccountSharesItsResolvedPathButNotItsName() throws {
        let support = scratchSupport()
        let real = AgentAccountHomes.directory(for: AgentAccountID("client"), provider: .claudeCode, support: support)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = real.deletingLastPathComponent().appending(path: "other")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let home = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID("client"), directory: link, isDefault: false
        )

        #expect(AgentAccountRemoval.directory(of: home, support: support) == nil)
    }

    @Test func theWarningNamesTheActionByWhatItDeletes() {
        #expect(AgentAccountRemoval.warning(forAccountNamed: "x", folderExists: true).actionTitle == "Remove account")
        #expect(AgentAccountRemoval.warningForUnfinishedSignIn(named: "x").actionTitle == "Remove folder")
    }

    @Test func anUnfinishedFolderOutsideTheAccountsRootIsNeverDeletedAndTheOwnerIsTold() throws {
        let support = scratchSupport()
        let outside = URL(filePath: TestScratch.unique("outside"), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let provider = AgentAccountHomes.root(support: support).appending(path: "claudeCode", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: provider, withIntermediateDirectories: true)
        let link = provider.appending(path: "client")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let orphan = AgentAccountHome(
            provider: .claudeCode, id: AgentAccountID("client"),
            directory: link.appending(path: "", directoryHint: .isDirectory), isDefault: false
        )

        #expect(throws: AgentAccountError.folderLeftAlone(orphan.directory.path)) {
            try AgentAccountRemoval.removeUnfinished(orphan, support: support, processes: { [] })
        }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }
}
