import Testing
import Foundation
@testable import Core

@Suite("The default permission mode", .scratchDirectory)
struct PermissionDefaultTests {
    @Test("a brand new session may act without asking")
    func fallbackIsFullAccess() {
        #expect(AppDefaults.fallbackPermissionMode == .bypassPermissions)
        #expect(PermissionMode.bypassPermissions.label(on: .codex) == "Full access")
    }

    @Test("every unstated starting point agrees with the fallback")
    func nothingRestatesTheDefault() {
        #expect(AppDefaults().permissionMode == .bypassPermissions)
        #expect(ComposerControls().permissionMode == .bypassPermissions)
        #expect(Session(workspaceID: WorkspaceID("w")).permissionMode == .bypassPermissions)
    }

    @Test("a store with nothing in it hands back full access")
    func emptyStoreLoadsTheFallback() async throws {
        let store = try makeTestStore("permission-default-empty")

        #expect(await AppDefaults.load(from: store).permissionMode == .bypassPermissions)
    }

    @Test("a mode chosen in Settings still beats the built-in")
    func theStoredChoiceWins() async throws {
        let store = try makeTestStore("permission-default-stored")
        try await store.setSetting(AppDefaults.Key.permissionMode, PermissionMode.auto.rawValue)

        let defaults = await AppDefaults.load(from: store)
        #expect(defaults.permissionMode == .auto)
        #expect(ComposerDefaults.resolve(repo: RepoSettings(), app: defaults).permissionMode == .auto)
    }

    @Test("plan mode still outranks it")
    func planModeStillWins() {
        var defaults = AppDefaults()
        defaults.planMode = true

        #expect(ComposerDefaults.resolve(repo: RepoSettings(), app: defaults).permissionMode == .plan)
    }

    @Test("a repository file has no say over it, so the default reaches an unconfigured repo")
    func aRepoFileCannotChangeIt() {
        let resolved = ComposerDefaults.resolve(repo: RepoSettings(), app: AppDefaults())

        #expect(resolved.permissionMode == .bypassPermissions)
    }

    @Test("the chat with no worktree is the one thing that does not take the default")
    func theConversationWithNoWorktreeIsTheException() {
        #expect(AskConversation.permissionMode != AppDefaults.fallbackPermissionMode)
        #expect(AskConversation.newSession().permissionMode == .auto)
        #expect(
            ComposerDefaults
                .resolve(repo: RepoSettings(), app: AppDefaults(), hasWorktree: false)
                .permissionMode == AskConversation.permissionMode
        )
    }

    @Test("on Claude Code it is the flag that stops the asking")
    func reachesClaudeCodeAsBypass() {
        #expect(AppDefaults.fallbackPermissionMode.cliValue == "bypassPermissions")
    }

    @Test("on Codex it is no approvals and no sandbox")
    func reachesCodexAsDangerFullAccess() {
        let mode = AppDefaults.fallbackPermissionMode
        #expect(CodexRunner.approvalPolicy(for: mode) == .never)
        #expect(CodexRunner.sandboxMode(for: mode) == .dangerFullAccess)
        #expect(CodexRunner.sandboxPolicy(for: mode, writableRoot: "/tmp/w")
            == .object(["type": .string("dangerFullAccess")]))
    }
}
