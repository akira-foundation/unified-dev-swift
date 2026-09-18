import Foundation
import Testing
@testable import Core

@Suite("Menu bar panel focus")
struct MenuBarPanelFocusTests {
    private func workspace(_ name: String) -> Workspace {
        Workspace(repoID: RepoID("repo"), name: name, branch: name, path: "/tmp/\(name)", baseBranch: "main")
    }

    private func content(
        providers: [MenuBarPanelContent.Provider] = [],
        agents: [MenuBarPanelContent.Agent] = [],
        more: Int = 0
    ) -> MenuBarPanelContent {
        MenuBarPanelContent(sentence: "", badges: [], providers: providers, agents: agents, moreAgents: more, notices: [])
    }

    @Test("walks the panel top to bottom, reaching only what is drawn")
    func order() {
        let a = workspace("a")
        let order = MenuBarPanelFocus.order(
            content: content(
                providers: [
                    .init(kind: .claudeCode, reading: .measured),
                    .init(kind: .codex, reading: .unavailable),
                ],
                agents: [.init(workspace: a, isWaiting: false)],
                more: 2
            ),
            foldable: [.claudeCode],
            showsKeepAwakeOptions: false
        )
        #expect(order == [
            .keepAwake, .keepAwakeOptions, .openApp,
            .fold(.claudeCode), .retry(.codex),
            .agent(a.id), .moreAgents,
            .settings, .quit,
        ])
    }

    @Test("open Keep Awake options join the walk, and a missing provider brings the setup link")
    func optionsAndSetup() {
        let order = MenuBarPanelFocus.order(content: content(), foldable: [], showsKeepAwakeOptions: true)
        #expect(order == [
            .keepAwake, .keepAwakeOptions,
            .keepAwakeChoice(.oneHour), .keepAwakeChoice(.twoHours),
            .keepAwakeChoice(.untilAgentsFinish), .keepAwakeChoice(.always), .keepAwakeSettings,
            .openApp, .setup, .settings, .quit,
        ])
    }

    @Test("the arrows move one step and stop at either end")
    func step() {
        let order: [MenuBarPanelFocus] = [.keepAwake, .openApp, .quit]
        #expect(MenuBarPanelFocus.step(from: nil, by: 1, in: order) == .keepAwake)
        #expect(MenuBarPanelFocus.step(from: nil, by: -1, in: order) == .quit)
        #expect(MenuBarPanelFocus.step(from: .keepAwake, by: 1, in: order) == .openApp)
        #expect(MenuBarPanelFocus.step(from: .quit, by: 1, in: order) == .quit)
        #expect(MenuBarPanelFocus.step(from: .keepAwake, by: -1, in: order) == .keepAwake)
        #expect(MenuBarPanelFocus.step(from: .settings, by: 1, in: order) == .keepAwake)
        #expect(MenuBarPanelFocus.step(from: nil, by: 1, in: []) == nil)
    }
}
