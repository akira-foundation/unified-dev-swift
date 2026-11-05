import SwiftUI
import Core

#if DEBUG
@MainActor
extension AgentAccountProbe {
    private static let grokNow = Date(timeIntervalSince1970: 1_793_790_000)

    private static let grokBilling = """
    {"config":{"creditUsagePercent":100.0,"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY",\
    "start":"2026-11-01T13:01:35.239+00:00","end":"2026-11-08T13:01:35.239+00:00"},\
    "prepaidBalance":{"val":0},"isUnifiedBillingUser":true},"subscription_tier":"SuperGrok Lite"}
    """

    private static func grokScene(_ name: String, billing: String) -> Scene {
        let payload = Data(billing.utf8)
        let codexWeek = AgentQuota(
            provider: .codex,
            window: .lasting(604_800, key: "secondary"),
            measure: .fraction(0.01),
            resetsAt: grokNow.addingTimeInterval(302_400),
            observedAt: grokNow
        )
        let quotas = AgentQuotaAdapters.quotas(fromRateLimitEvent: payload, at: grokNow) + [codexWeek]
        let grok = GrokQuotaSource().account(from: payload, at: grokNow)
        let accounts: [AgentKind: AgentAccount] = grok.map { [.grok: $0] } ?? [:]
        let content = MenuBarPanelContent.make(MenuBarPanelContent.Input(
            workspaces: [],
            running: [],
            waiting: [],
            agentsByWorkspace: [:],
            quotas: quotas,
            accounts: accounts,
            unanswered: [],
            withoutLimits: [],
            lastReported: [:],
            layout: UsageLayout(),
            hold: .none,
            now: grokNow
        ))
        let height: CGFloat = 420
        return Scene(
            name: "usage-\(name)",
            size: CGSize(width: MenuBarPanelPlacement.width, height: height),
            view: AnyView(
                VStack(spacing: MenuBarModuleStyle.gap) {
                    ForEach(content.providers) { provider in
                        MenuBarProviderModule(
                            provider: provider,
                            plan: accounts[provider.kind]?.plan,
                            options: UsageMenuModel.shared.options,
                            now: grokNow,
                            retry: {},
                            toggleFold: {}
                        )
                    }
                }
                .padding(MenuBarModuleStyle.gap)
                .frame(width: MenuBarPanelPlacement.width, height: height, alignment: .top)
                .background(Color(nsColor: .windowBackgroundColor))
            )
        )
    }

    static func grokUsageScenes() -> [Scene] {
        [
            grokScene("grok-spent", billing: grokBilling),
            grokScene("grok-partial", billing: grokBilling.replacingOccurrences(of: "100.0", with: "37.5")),
        ]
    }
}
#endif
