import Foundation

public enum SpendProviders {
    public static func onThisMac(
        accounts: [AgentKind: AgentAccount],
        quotas: [AgentQuota],
        unanswered: Set<AgentKind>,
        withoutLimits: Set<AgentKind>,
        census: SpendCensus
    ) -> Set<AgentKind> {
        var found = Set(accounts.keys)
        found.formUnion(quotas.map(\.provider))
        found.formUnion(unanswered)
        found.formUnion(withoutLimits)
        found.formUnion(
            AgentKind.allCases.filter { census[$0]?.keepsTranscripts == true }
        )
        return found
    }
}
