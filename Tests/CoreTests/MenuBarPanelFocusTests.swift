import Foundation
import Testing
@testable import Core

@Suite("Menu bar panel focus")
struct MenuBarPanelFocusTests {
    private func workspace(_ name: String) -> Workspace {
        Workspace(repoID: RepoID("repo"), name: name, branch: name, path: "/tmp/\(name)", baseBranch: "main")
    }

    private var foldable: UsageLayout.Section {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let metric = { (key: String) in
            UsageCatalogue.metric(for: AgentQuota(
                provider: .claudeCode, window: .named(key), measure: .fraction(0.1), resetsAt: nil, observedAt: now
            ))
        }
        return UsageLayout.Section(
            provider: .claudeCode, alwaysVisible: [metric("five_hour")], onDemand: [metric("seven_day")], isExpanded: false
        )
    }

    private func content(
        providers: [MenuBarPanelContent.Provider] = [],
        agents: [MenuBarPanelContent.Agent] = [],
        more: Int = 0
    ) -> MenuBarPanelContent {
        MenuBarPanelContent(
            sentence: "", badges: [], providers: providers, agents: agents, moreAgents: more, notices: [],
            needsSetup: providers.isEmpty
        )
    }

    @Test("walks the panel top to bottom, reaching only what is drawn")
    func order() {
        let a = workspace("a")
        let order = MenuBarPanelFocus.order(
            content: content(
                providers: [
                    .init(kind: .claudeCode, reading: .measured, section: foldable),
                    .init(kind: .codex, reading: .unavailable),
                ],
                agents: [.init(workspace: a, isWaiting: false)],
                more: 2
            ),
            showsKeepAwakeOptions: false
        )
        #expect(order == [
            .keepAwake, .keepAwakeOptions,
            .fold(.claudeCode), .retry(.codex),
            .agent(a.id), .moreAgents,
            .settings, .quit,
        ])
    }

    @Test("open Keep Awake options join the walk, and a missing provider brings the setup link")
    func optionsAndSetup() {
        let order = MenuBarPanelFocus.order(content: content(), showsKeepAwakeOptions: true)
        #expect(order == [
            .keepAwake, .keepAwakeOptions,
            .keepAwakeChoice(.oneHour), .keepAwakeChoice(.twoHours),
            .keepAwakeChoice(.untilAgentsFinish), .keepAwakeChoice(.always), .keepAwakeSettings,
            .setup, .settings, .quit,
        ])
    }

    @Test("the arrows move one step and stop at either end")
    func step() {
        let order: [MenuBarPanelFocus] = [.keepAwake, .settings, .quit]
        #expect(MenuBarPanelFocus.step(from: nil, by: 1, in: order) == .keepAwake)
        #expect(MenuBarPanelFocus.step(from: nil, by: -1, in: order) == .quit)
        #expect(MenuBarPanelFocus.step(from: .keepAwake, by: 1, in: order) == .settings)
        #expect(MenuBarPanelFocus.step(from: .quit, by: 1, in: order) == .quit)
        #expect(MenuBarPanelFocus.step(from: .keepAwake, by: -1, in: order) == .keepAwake)
        #expect(MenuBarPanelFocus.step(from: .moreAgents, by: 1, in: order) == .keepAwake)
        #expect(MenuBarPanelFocus.step(from: nil, by: 1, in: []) == nil)
    }
}
