import Testing
import Foundation
@testable import Core

@Suite("The account scope a chat runs under", .tags(.persistence), .scratchDirectory)
struct ChatAccountScopeTests {
    private let user = URL(filePath: "/Users/someone")
    private let akira = ProfileID("akira")
    private let debtges = ProfileID("debtges")

    private var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }

    private func workspace() -> Workspace {
        Workspace(
            repoID: RepoID("api"), name: "w", branch: "feature/w",
            path: "/tmp/worktree", baseBranch: "main"
        )
    }

    @Test("an Ask chat runs under the active profile when no turn holds a pin")
    func askFollowsTheActiveProfile() {
        let scope = AccountScope.chat(workspace: nil, activeProfile: akira, pinnedProfile: nil)

        #expect(scope == AccountScope(profileID: akira))
    }

    @Test("an Ask chat keeps the profile its turn is pinned to after the owner switches")
    func askKeepsItsPinnedProfile() {
        let scope = AccountScope.chat(workspace: nil, activeProfile: debtges, pinnedProfile: akira)

        #expect(scope == AccountScope(profileID: akira))
    }

    @Test("a workspace chat runs under its project, whichever profile is on screen")
    func workspaceChatIgnoresTheActiveProfile() {
        let workspace = workspace()

        let scope = AccountScope.chat(workspace: workspace, activeProfile: akira, pinnedProfile: debtges)

        #expect(scope == AccountScope(workspaceID: workspace.id, repoID: workspace.repoID))
    }

    @Test("an Ask chat started in a profile with its own account resolves that account, not the default")
    func askResolvesTheProfileAccount() async throws {
        let store = try makeTestStore("chat-account-scope")
        let profile = try await store.createProfile(name: "Akira", colour: Accent.all[1], symbol: "star")
        let path = TestScratch.unique("accounts") + "/akira"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let own = AgentAccountRow(
            id: AgentAccountID("preview.claudeCode.akira"), provider: .claudeCode, directory: path,
            profileID: profile.id
        )
        try await store.add(own)
        try await store.chooseAgentAccount(ChosenAgentAccount(AgentAccountHome(own)), forProfile: profile.id)
        let scope = AccountScope.chat(workspace: nil, activeProfile: profile.id, pinnedProfile: nil)

        let home = try await AgentAccountResolver.resolve(
            workspaceID: scope.workspaceID, repoID: scope.repoID, profileID: scope.profileID,
            store: store, defaults: [defaultClaude]
        ).home(for: .claudeCode)

        #expect(home?.id == own.id)
    }
}
