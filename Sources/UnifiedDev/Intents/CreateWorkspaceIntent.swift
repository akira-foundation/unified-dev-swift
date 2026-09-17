import AppIntents
import Foundation
import Core

struct CreateWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Workspace"

    static let description = IntentDescription(
        """
        Cuts a git worktree in a Unified Dev project, opens it, and starts an agent on the prompt. \
        Returns the workspace once Unified Dev has created it.
        """,
        categoryName: "Workspaces",
        resultValueName: "Workspace"
    )

    static let openAppWhenRun = true

    @Parameter(title: "Project", description: "The Unified Dev project to cut the worktree from.")
    var project: ProjectEntity

    @Parameter(
        title: "Prompt",
        description: "What the agent should do. Unified Dev names the workspace and its branch from this.",
        inputOptions: String.IntentInputOptions(multiline: true)
    )
    var prompt: String

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$prompt) in \(\.$project)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<WorkspaceEntity> {
        let store = try await IntentDatabase.store()
        guard let repo = try await store.repo(id: project.id) else {
            throw IntentFailure.unknownProject
        }

        guard await RunningApp.waitUntilReady() else { throw IntentFailure.appNeverAppeared }

        let created = try await RunningApp.startWorkspace(in: repo, prompt: prompt)

        let entity = WorkspaceEntity(
            workspace: created,
            project: repo.name,
            isAgentRunning: await WorkspaceLookup.isAgentRunning(workspaceID: created.id, store: store),
            isAwaitingPermission: await WorkspaceLookup.isAwaitingPermission(workspaceID: created.id, store: store),
            pullRequest: nil
        )
        return .result(value: entity, dialog: "Started \(created.name) in \(repo.name).")
    }
}
