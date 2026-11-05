import SwiftUI
import Core

#if DEBUG
@MainActor
extension AgentAccountProbe {
    private static let offerNow = Date(timeIntervalSince1970: 1_800_000_000)

    private static func offerHome(_ name: String, isDefault: Bool = false) -> AgentAccountHome {
        AgentAccountHome(
            provider: .claudeCode,
            id: isDefault ? AgentAccountHome.defaultID(for: .claudeCode) : AgentAccountID(name),
            directory: URL(filePath: "/Users/ada/accounts/claude-code/\(name)", directoryHint: .isDirectory),
            isDefault: isDefault
        )
    }

    private static func offerStanding(
        _ home: AgentAccountHome,
        email: String?,
        report: AgentAccountLiveness.CliReport = .unanswered,
        doubt: String? = nil
    ) -> AgentAccountStanding {
        AgentAccountStanding(
            home: home, identity: AgentAccountIdentity(email: email), cliReport: report, isolationDoubt: doubt
        )
    }

    private static let spentSession = AgentQuota(
        provider: .claudeCode,
        window: .named("five_hour"),
        measure: .fraction(1),
        resetsAt: offerNow.addingTimeInterval(7_500),
        observedAt: offerNow
    )

    private static let weekly = AgentQuota(
        provider: .claudeCode,
        window: .named("seven_day"),
        measure: .fraction(0.61),
        resetsAt: offerNow.addingTimeInterval(302_400),
        observedAt: offerNow
    )

    private static func offerScene(
        _ name: String,
        others: [AgentAccountStanding],
        spent: Bool = true,
        signedOut: AgentAccountSignOut.Cause? = nil,
        running: Bool = false,
        height: CGFloat
    ) -> Scene {
        let current = offerHome("default", isDefault: true)
        let standings = [offerStanding(current, email: "ada@home.example")] + others
        let quotas = spent ? [spentSession, weekly] : [weekly]
        let session = Session(workspaceID: nil, agentSessionID: "agent-session-1")
        let offer = QuotaAccountOffer.make(QuotaAccountOffer.Input(
            session: session,
            current: current,
            standings: standings,
            notices: MenuBarPanelContent.limitNotices(quotas, at: offerNow),
            signedOut: signedOut,
            isTurnInFlight: running,
            lastTurnEndedCleanly: false,
            workspaceName: "billing",
            now: offerNow
        ))
        let content = MenuBarPanelContent.make(MenuBarPanelContent.Input(
            workspaces: [],
            running: [],
            waiting: [],
            runningAgents: 0,
            quotas: quotas,
            accounts: [:],
            unanswered: [],
            withoutLimits: [],
            lastReported: [:],
            layout: UsageLayout(),
            hold: .none,
            now: offerNow,
            offers: offer.map { [.claudeCode: $0] } ?? [:]
        ))
        return Scene(
            name: "offer-\(name)",
            size: CGSize(width: MenuBarPanelPlacement.width, height: height),
            view: AnyView(
                VStack(spacing: MenuBarModuleStyle.gap) {
                    MenuBarStatusModule(content: content, focus: nil, openSettings: {})
                    ForEach(content.providers) { provider in
                        MenuBarProviderModule(
                            provider: provider,
                            plan: "Max",
                            options: UsageMenuModel.shared.options,
                            now: offerNow,
                            retry: {},
                            toggleFold: {},
                            useAccount: { _ in }
                        )
                    }
                }
                .padding(MenuBarModuleStyle.gap)
                .frame(width: MenuBarPanelPlacement.width, height: height, alignment: .top)
                .background(Color(nsColor: .windowBackgroundColor))
            )
        )
    }

    static func offerScenes() -> [Scene] {
        let client = offerStanding(offerHome("client"), email: "ada@client.example")
        let lab = offerStanding(offerHome("lab"), email: "ada@lab.example")
        let old = offerStanding(offerHome("old"), email: "ada@old.example", report: .claimsNoSession)
        let old2 = offerStanding(offerHome("old2"), email: "ada@older.example", report: .claimsNoSession)
        let doubtful = offerStanding(
            offerHome("keyring"), email: "ada@keyring.example",
            doubt: "It keeps its login in the system keychain here, which a separate directory does not keep apart."
        )
        return [
            offerScene("two-signed-out", others: [old, old2], height: 520),
            offerScene("only-signed-out-others", others: [old], spent: false, signedOut: .notSignedIn, height: 400),
            offerScene("isolation-doubt", others: [doubtful], height: 600),
            offerScene("zero-others", others: [], height: 280),
            offerScene("one-other", others: [client], height: 480),
            offerScene("two-others", others: [client, lab], height: 520),
            offerScene("turn-running", others: [client], running: true, height: 480),
            offerScene("one-signed-out", others: [client, old], height: 540),
            offerScene("not-signed-in-alone", others: [], spent: false, signedOut: .notSignedIn, height: 330),
            offerScene("not-signed-in", others: [client], spent: false, signedOut: .notSignedIn, height: 480),
            offerScene("signed-out-after-switch", others: [lab], spent: false, signedOut: .afterSwitch, height: 500),
        ]
    }
}
#endif
