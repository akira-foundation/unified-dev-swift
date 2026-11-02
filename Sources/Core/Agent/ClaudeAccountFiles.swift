import Foundation

public struct ClaudeAccountFiles: Sendable, Hashable {
    public var identity: Data?
    public var credential: Data?

    public init(identity: Data? = nil, credential: Data? = nil) {
        self.identity = identity
        self.credential = credential
    }

    public var plan: String? { plan(reportedSubscription: nil, reportedTier: nil) }

    public func plan(reportedSubscription: String?, reportedTier: String?) -> String? {
        let account = identity.flatMap(JSONValue.parse)?["oauthAccount"]
        let oauth = credential.flatMap(JSONValue.parse)?["claudeAiOauth"]
        let subscription = Self.firstNonEmpty(
            account?["organizationType"]?.stringValue,
            oauth?["subscriptionType"]?.stringValue,
            reportedSubscription
        )
        let tier = Self.firstNonEmpty(
            account?["organizationRateLimitTier"]?.stringValue,
            oauth?["rateLimitTier"]?.stringValue,
            reportedTier
        )
        return AgentAccountReader.claudePlan(subscription ?? "", rateLimitTier: tier)
    }

    private static func firstNonEmpty(_ candidates: String?...) -> String? {
        candidates.lazy.compactMap { $0 }.first { !$0.isEmpty }
    }
}
