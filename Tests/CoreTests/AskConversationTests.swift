import Testing
import Foundation
@testable import Core

@Suite("Ask Unified Dev's conversation", .tags(.persistence), .scratchDirectory)
struct AskConversationTests {
    @Test("it runs in its own directory beside the database, and not in a home directory")
    func directoryIsBesideTheDatabase() {
        let directory = AskConversation.directory(besideDatabaseAt: "/tmp/somewhere/unifieddev.sqlite")
        #expect(directory == "/tmp/somewhere/Ask")
        #expect(!directory.hasSuffix("unifieddev.sqlite"))
    }

    @Test("two copies of Unified Dev get two directories")
    func devCopyIsSeparate() {
        let owner = AskConversation.directory(besideDatabaseAt: "/tmp/Unified Dev/unifieddev.sqlite")
        let dev = AskConversation.directory(besideDatabaseAt: "/tmp/Unified Dev (Dev)/unifieddev.sqlite")
        #expect(owner != dev)
    }

    @Test("the directory is made, and is empty")
    func directoryIsMadeEmpty() throws {
        let database = TestScratch.unique("ask-cwd") + "/unifieddev.sqlite"
        try FileManager.default.createDirectory(
            atPath: (database as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )

        let path = try #require(AskConversation.prepareDirectory(besideDatabaseAt: database))
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty)

        #expect(AskConversation.prepareDirectory(besideDatabaseAt: database) == path)
    }

    @Test("a new chat has no workspace and opens on Ask")
    func newSessionOpensOnAsk() {
        let session = AskConversation.newSession()
        #expect(session.workspaceID == nil)
        #expect(session.permissionMode == .auto)
        #expect(session.permissionMode != AppDefaults.fallbackPermissionMode)
        #expect(session.title == AskConversation.title)
        #expect(session.state == .idle)
    }

    @Test("the owner's default permission mode does not land on a chat with no worktree")
    func defaultsDoNotOverruleTheMode() {
        var defaults = AppDefaults()
        defaults.permissionMode = .bypassPermissions
        defaults.planMode = false

        let inWorktree = ComposerDefaults.resolve(repo: RepoSettings(), app: defaults)
        #expect(inWorktree.permissionMode == .bypassPermissions)

        let ask = ComposerDefaults.resolve(repo: RepoSettings(), app: defaults, hasWorktree: false)
        #expect(ask.permissionMode == AskConversation.permissionMode)
        #expect(ask.model == inWorktree.model)
        #expect(ask.effort == inWorktree.effort)
    }

    @Test("start in plan mode does not reach it either")
    func planModeDoesNotOverruleTheMode() {
        var defaults = AppDefaults()
        defaults.planMode = true

        #expect(ComposerDefaults.resolve(repo: RepoSettings(), app: defaults).permissionMode == .plan)
        #expect(
            ComposerDefaults.resolve(repo: RepoSettings(), app: defaults, hasWorktree: false)
                .permissionMode == AskConversation.permissionMode
        )
    }

    @Test("the mode goes back to Ask on the next launch, and not before")
    func theModeIsReappliedEachLaunch() {
        #expect(
            AskConversation.modeOnOpening(stored: .bypassPermissions, isFirstOpenSinceLaunch: true)
                == AskConversation.permissionMode
        )

        #expect(
            AskConversation.modeOnOpening(stored: .bypassPermissions, isFirstOpenSinceLaunch: false)
                == nil
        )

        #expect(
            AskConversation.modeOnOpening(
                stored: AskConversation.permissionMode, isFirstOpenSinceLaunch: true
            ) == nil
        )
    }

    @Test("the permission menu says what a mode means with no worktree")
    func theMenuSaysWhatAModeMeansHere() throws {
        let inWorktree = ComposerControls(
            session: Session(workspaceID: WorkspaceID("w1")), isFastMode: false, outputStyle: ""
        )
        #expect(inWorktree.hasWorktree)
        #expect(inWorktree.permissionModeNote == nil)

        let ask = ComposerControls(
            session: AskConversation.newSession(), isFastMode: false, outputStyle: ""
        )
        #expect(!ask.hasWorktree)
        let note = try #require(ask.permissionModeNote)
        #expect(note.contains("whole machine"))
        #expect(note.contains("Unified Dev next starts"))
    }

    @Test("the opening words offer something rather than apologise")
    func openingWordsOffer() {
        #expect(!AskConversation.emptyHeading.isEmpty)
        #expect(!AskConversation.placeholder.isEmpty)
        #expect(!AskConversation.emptyDetail.contains("cannot"))
        #expect(!AskConversation.emptyDetail.lowercased().contains("worktree"))
        #expect(!AskConversation.emptyHeading.lowercased().contains("worktree"))
    }
}
