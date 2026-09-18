import SwiftUI
import Core

struct MenuBarPanelView: View {
    let app: AppModel
    let model: UsageMenuModel
    let actions: MenuBarPanelActions
    let onHeight: (CGFloat) -> Void

    @State private var keepAwake = KeepAwakeModel.shared
    @State private var showsKeepAwakeOptions = false
    @AppStorage(SleepPrevention.settingKey) private var whileAgentsRun = SleepPrevention.isOnByDefault
    @FocusState private var focus: MenuBarPanelFocus?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let content = MenuBarPanelContent.make(app.menuBarPanelInput(
                layout: model.layout, session: keepAwake.session, whileAgentsRun: whileAgentsRun, at: now
            ))
            let sections = usageSections(at: now)
            ScrollView {
                GlassEffectContainer(spacing: MenuBarModuleStyle.gap) {
                    VStack(spacing: MenuBarModuleStyle.gap) {
                        modules(content, sections: sections, now: now)
                    }
                }
                .padding(MenuBarModuleStyle.gap)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    onHeight(height)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .onMoveCommand { direction in
                let offset = direction == .up || direction == .left ? -1 : 1
                focus = MenuBarPanelFocus.step(from: focus, by: offset, in: MenuBarPanelFocus.order(
                    content: content,
                    foldable: Set(sections.values.filter { !$0.onDemand.isEmpty }.map(\.provider)),
                    showsKeepAwakeOptions: showsKeepAwakeOptions
                ))
            }
        }
        .frame(width: MenuBarPanelPlacement.width)
    }

    private func usageSections(at now: Date) -> [AgentKind: UsageLayout.Section] {
        let metrics = UsageCatalogue.metrics(quotas: app.quotas, accounts: app.accounts, at: now)
        return Dictionary(
            model.layout.sections(for: metrics).map { ($0.provider, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    @ViewBuilder
    private func modules(
        _ content: MenuBarPanelContent,
        sections: [AgentKind: UsageLayout.Section],
        now: Date
    ) -> some View {
        MenuBarChipsRow(
            runningCount: app.runningAgentCount,
            now: now,
            showsOptions: $showsKeepAwakeOptions,
            focus: $focus,
            openApp: actions.openApp,
            openSettings: { actions.openSettings(.menuBar) }
        )
        MenuBarStatusModule(content: content, focus: $focus, openSettings: { actions.openSettings(.agents) })
        ForEach(content.providers) { provider in
            MenuBarProviderModule(
                provider: provider,
                section: sections[provider.kind],
                plan: app.accounts[provider.kind]?.plan,
                options: model.options,
                now: now,
                focus: $focus,
                retry: actions.retryUsage,
                toggleFold: { model.update { $0.toggleExpanded(provider.kind) } }
            )
        }
        MenuBarAgentsModule(
            agents: content.agents,
            more: content.moreAgents,
            focus: $focus,
            open: actions.openWorkspace,
            openRunning: actions.openRunning
        )
        MenuBarFooterModule(focus: $focus, openSettings: { actions.openSettings(nil) }, quit: actions.quit)
    }
}
