import Foundation

public struct WelcomeAnchorCandidate: Sendable, Hashable {
    public let role: WindowDismissal.Role
    public let isVisible: Bool
    public let isSheet: Bool
    public let isPanel: Bool
    public let hasParent: Bool

    public init(
        role: WindowDismissal.Role,
        isVisible: Bool,
        isSheet: Bool = false,
        isPanel: Bool = false,
        hasParent: Bool = false
    ) {
        self.role = role
        self.isVisible = isVisible
        self.isSheet = isSheet
        self.isPanel = isPanel
        self.hasParent = hasParent
    }
}

public enum WelcomeAnchor {
    public static func canAnchor(_ candidate: WelcomeAnchorCandidate) -> Bool {
        guard candidate.isVisible, candidate.role == .workspace else { return false }
        return !candidate.isSheet && !candidate.isPanel && !candidate.hasParent
    }
}
