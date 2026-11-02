import Foundation

public struct ClaudeAccountFiles: Sendable {
    private let subscription: String?
    private let tier: String?

    public init(identity: Data? = nil, credential: Data? = nil) {
        let account = identity.flatMap(JSONValue.parse)?["oauthAccount"]
        let oauth = credential.flatMap(JSONValue.parse)?["claudeAiOauth"]
        subscription = Self.firstNonEmpty(
            account?["organizationType"]?.stringValue,
            oauth?["subscriptionType"]?.stringValue
        )
        tier = Self.firstNonEmpty(
            account?["organizationRateLimitTier"]?.stringValue,
            oauth?["rateLimitTier"]?.stringValue
        )
    }

    public var plan: String? { plan(reportedSubscription: nil, reportedTier: nil) }

    public func plan(reportedSubscription: String?, reportedTier: String?) -> String? {
        AgentAccountReader.claudePlan(
            Self.firstNonEmpty(subscription, reportedSubscription) ?? "",
            rateLimitTier: Self.firstNonEmpty(tier, reportedTier)
        )
    }

    private static func firstNonEmpty(_ candidates: String?...) -> String? {
        candidates.lazy.compactMap { $0 }.first { !$0.isEmpty }
    }
}
