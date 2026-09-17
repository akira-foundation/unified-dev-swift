import Foundation

public struct ComposerDefaults: Equatable {
    public var model: String
    public var effort: String
    public var permissionMode: PermissionMode
    public var backend: AgentKind = .claudeCode
    public var interactionMode: InteractionMode = .build

    public static func resolve(
        repo: RepoSettings,
        app: AppDefaults,
        hasWorktree: Bool = true,
        running: AgentKind = .claudeCode,
        models: [AgentKind: [AgentModel]] = [:]
    ) -> ComposerDefaults {
        let model = firstNonEmpty(
            repo.defaultModel,
            app.storedModel,
            repo.homeDefaultModel,
            fallback: app.model
        )
        let resolved = DefaultBackend.resolve(
            model: model,
            effort: firstNonEmpty(
                repo.defaultEffort,
                app.storedEffort,
                repo.homeDefaultEffort,
                fallback: app.effort
            ),
            app: app,
            running: running,
            models: models
        )
        return ComposerDefaults(
            model: resolved.model,
            effort: resolved.effort,
            permissionMode: (hasWorktree
                ? (app.planMode && resolved.kind != .codex ? .plan : app.permissionMode)
                : AskConversation.permissionMode).nearest(on: resolved.kind),
            backend: resolved.kind,
            interactionMode: hasWorktree && app.planMode && resolved.kind == .codex ? .plan : .build
        )
    }

    public static func firstNonEmpty(_ candidates: String?..., fallback: String) -> String {
        for candidate in candidates {
            if let candidate, !candidate.trimmingCharacters(in: .whitespaces).isEmpty {
                return candidate
            }
        }
        return fallback
    }
}
