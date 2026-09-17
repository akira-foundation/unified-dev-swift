import Foundation

public struct PermissionScopeOffer: Sendable, Hashable {
    public let scopes: [PermissionScope]
    public let explanation: String

    public init(scopes: [PermissionScope], explanation: String) {
        self.scopes = scopes
        self.explanation = explanation
    }

    public var prominent: PermissionScope { scopes.first ?? .once }

    public var widens: Bool { scopes.count > 1 }

    public static func of(ask: PermissionAsk, project: String?) -> PermissionScopeOffer {
        guard ask.canWiden else {
            return PermissionScopeOffer(scopes: [.once], explanation: reasonThereIsNoRule(for: ask))
        }

        guard let project, !project.isEmpty else {
            return PermissionScopeOffer(
                scopes: [.session, .once],
                explanation: PermissionScope.session.consequence(rule: ask.ruleText, project: "")
                    + " There is no project behind this conversation, and a rule that lasts is "
                    + "stored against one, so this session is as far as an allow can reach here."
            )
        }

        return PermissionScopeOffer(
            scopes: [.project, .session, .once],
            explanation: PermissionScope.project.consequence(rule: ask.ruleText, project: project)
        )
    }

    private static func reasonThereIsNoRule(for ask: PermissionAsk) -> String {
        guard !ask.rules.isEmpty else {
            return "No rule was offered for this, so it can only be allowed once."
        }
        return "\(ask.ruleText) cannot be granted from here: "
            + "the agent asked for this one to be decided on its own."
    }
}

public extension PermissionScope {
    var compactLabel: String {
        switch self {
        case .once: "Once"
        case .session: "This session"
        case .project: "Always allow"
        }
    }
}
