import Foundation

public enum OnboardingAgentChoice {
    public static func candidates(in report: SetupReport) -> [AgentKind] {
        let agents = SetupTool.displayOrder.filter { $0.agentKind?.canRunWorkspaces == true }
        guard agents.allSatisfy({ report.outcome(for: $0).isSettled }) else { return [] }
        return agents.filter { report.outcome(for: $0).isReady }.compactMap(\.agentKind)
    }

    public static func isOffered(in report: SetupReport, hasDefaultPreset: Bool = false) -> Bool {
        guard !hasDefaultPreset else { return false }
        return candidates(in: report).count > 1
    }

    public static func defaults(
        choosing kind: AgentKind,
        from current: AppDefaults,
        models: [AgentModel]
    ) -> AppDefaults? {
        guard kind != current.backend else { return current }

        let model: String
        let effort: String
        if kind == .claudeCode {
            model = AppDefaults.fallbackModel
            effort = AppDefaults.fallbackEffort
        } else {
            guard let chosen = AgentModel.selection(requested: nil, from: models) else { return nil }
            model = chosen.id
            effort = chosen.resolvedEffort(preferring: current.effort)
        }

        var next = current
        let reviewFollows = current.reviewBackend == current.backend && current.reviewModel == current.model
        next.model = model
        next.effort = effort
        next.backend = kind
        next.storedModel = model
        next.storedEffort = effort
        if reviewFollows {
            next.reviewModel = model
            next.reviewEffort = effort
            next.reviewBackend = kind
        }
        return next
    }
}
