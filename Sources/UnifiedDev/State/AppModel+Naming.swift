import Foundation
import Core

extension AppModel {
    func shouldNameAutomatically(name: String?, prompt: String, opensWith: WorkspaceStartMode) -> Bool {
        WorkspaceNaming.shouldName(
            userSuppliedName: name,
            prompt: prompt,
            isChatWorkspace: opensWith == .chat,
            isEnabled: WorkspaceNamingPreferences().isEnabled,
            isAgentAvailable: WorkspaceNamer.isAvailable
        )
    }

    func placeholderName() async -> String {
        var taken = Set(workspaces.map(\.name))
        taken.formUnion(await archivedWorkspaces().map(\.name))
        return WorkspaceNaming.placeholder(avoiding: taken)
    }

    func beginAutomaticNaming(
        workspace: Workspace,
        repo: Repo,
        prompt: String,
        placeholder: String
    ) {
        Task { [weak self] in
            await self?.nameAutomatically(
                workspace: workspace,
                repo: repo,
                prompt: prompt,
                placeholder: placeholder
            )
        }
    }

    private func nameAutomatically(
        workspace: Workspace,
        repo: Repo,
        prompt: String,
        placeholder: String
    ) async {
        guard let manager else { return }

        let branchPrefix = SettingsLoader.load(repo: repo.path).branchPrefix
        let template = PromptOverrides().template(for: .nameWorkspace)

        let suggested = await WorkspaceNamer().suggest(
            task: prompt,
            project: repo.name,
            template: template,
            branchPrefix: branchPrefix
        )

        let suggestion = suggested ?? WorkspaceNameSuggestion(
            name: Git.title(from: prompt),
            branch: ""
        )

        let hasPullRequest = WorkspacePullRequests.shared.pullRequest(for: workspace.id) != nil

        let outcome = try? await manager.applyName(
            suggestion,
            to: workspace.id,
            placeholder: placeholder,
            hasPullRequest: hasPullRequest
        )
        guard let result = outcome, result.didRename else { return }

        WorkspaceNameReveals.shared.announce(
            workspaceID: result.workspace.id,
            name: result.workspace.name
        )

        if let notice = result.notice {
            self.notice = Notice(message: notice)
        }
    }
}
