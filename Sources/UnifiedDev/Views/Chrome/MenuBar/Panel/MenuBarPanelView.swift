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
    @State private var showsFocus = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let input = app.menuBarPanelInput(
                layout: model.layout, session: keepAwake.session, whileAgentsRun: whileAgentsRun, at: now
            )
            let content = MenuBarPanelContent.make(input)
            ScrollView {
                VStack(spacing: MenuBarModuleStyle.gap) {
                    modules(content, hold: input.hold, now: now)
                }
                .padding(MenuBarModuleStyle.edge)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    onHeight(height)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .menuBarPanelPlatter()
            .environment(\.menuBarPanelShowsFocus, showsFocus)
            .onKeyPress(.tab) {
                showsFocus = true
                return .ignored
            }
            .onMoveCommand { direction in
                showsFocus = true
                let offset = direction == .up || direction == .left ? -1 : 1
                focus = MenuBarPanelFocus.step(from: focus, by: offset, in: MenuBarPanelFocus.order(
                    content: content,
                    showsKeepAwakeOptions: showsKeepAwakeOptions
                ))
            }
        }
        .frame(width: MenuBarPanelPlacement.width)
    }

    @ViewBuilder
    private func modules(
        _ content: MenuBarPanelContent,
        hold: KeepAwake.Hold,
        now: Date
    ) -> some View {
        MenuBarKeepAwakeChip(
            hold: hold,
            now: now,
            showsOptions: $showsKeepAwakeOptions,
            focus: $focus,
            openSettings: { actions.openSettings(.menuBar) }
        )
        MenuBarStatusModule(content: content, focus: $focus, openSettings: { actions.openSettings(.agents) })
        ForEach(content.providers) { provider in
            MenuBarProviderModule(
                provider: provider,
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
