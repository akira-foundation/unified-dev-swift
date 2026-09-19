import SwiftUI
import Core

struct WindowToolbar: ToolbarContent {
    let app: AppModel
    let centreWidth: CGFloat
    let startFreshAskConversation: () -> Void

    @FocusedValue(\.homeScopeCounts) private var homeCounts: HomeScopeCounts?

    @FocusedValue(\.notesFormatting) private var notesFormatting: NotesFormattingContext?

    var body: some ToolbarContent {
        if app.selection == .home {
            ToolbarItemGroup(placement: .principal) {
                homeScopePicker

                if HomeOrder.applies(scope: app.homeFilter.scope, searching: app.homeFilter.isSearching) {
                    homeOrderPicker
                }
            }
        }

        if let tabs = conversationTabs {
            ToolbarItem(placement: .principal) {
                let width = ToolbarTabsWidth.width(inColumn: centreWidth)
                tabs
                    .frame(width: width)
                    .id(width.rounded())
            }
            .sharedBackgroundVisibility(.hidden)
        }

        if let notesFormatting {
            NotesToolbar(context: notesFormatting)
        }

        if let model = app.selectedModel {
            ToolbarItem(placement: .primaryAction) {
                NewTabMenu(model: model)
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)
        }

        if app.selection == .home {
            ToolbarItem(placement: .primaryAction) {
                homeProjectMenu
            }
        }

        if app.selection == .ask, app.ask.session != nil {
            ToolbarItem(placement: .primaryAction) {
                Button(action: startFreshAskConversation) {
                    Image(systemName: "square.and.pencil")
                }
                .help("Start a new Ask Unified Dev conversation")
                .accessibilityLabel("Start a new Ask Unified Dev conversation")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                SearchPanelModel.shared.open(app: app)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Search workspaces, transcripts and commands")
            .accessibilityLabel("Search workspaces, transcripts and commands")
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)
    }

    static func showsTabs(in app: AppModel) -> Bool {
        switch app.selection {
        case .workspace:
            guard let model = app.selectedModel else { return false }
            let tabs = WorkspaceTabsStore.shared
            let entries = tabs.entries(in: model)
            let paneCount = tabs.selectedTab(in: model, entries: entries)
                .map { tabs.layout(of: $0).paneCount } ?? 1
            return ToolbarTabsWidth.showsStrip(
                tabCount: entries.count,
                paneCount: paneCount,
                isRenaming: TabRenameField.shared.id(in: model.workspace.id, among: entries) != nil
            )
        case .ask:
            return ToolbarTabsWidth.showsStrip(tabCount: app.ask.sessions.count)
        default:
            return false
        }
    }

    private var conversationTabs: AnyView? {
        guard Self.showsTabs(in: app) else { return nil }
        if app.selection == .ask { return AnyView(AskTabStrip()) }
        guard let model = app.selectedModel else { return nil }
        return AnyView(SessionTabsView(model: model))
    }

    private var homeScopePicker: some View {
        Picker(
            "Scope",
            selection: Binding(
                get: { app.homeFilter.scope },
                set: { app.homeFilter.scope = $0 }
            )
        ) {
            ForEach(HomeScope.offered(searching: app.homeFilter.isSearching), id: \.self) { scope in
                Text(homeScopeTitle(scope))
                    .tag(scope)
                    .accessibilityLabel(homeScopeAccessibilityLabel(scope))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .help("Choose which work Home lists")
    }

    private func homeScopeTitle(_ scope: HomeScope) -> String {
        let searching = app.homeFilter.isSearching
        let label = scope.label(searching: searching)
        guard let badge = homeCounts?.badge(of: scope, searching: searching) else { return label }
        return "\(label) \(badge)"
    }

    private func homeScopeAccessibilityLabel(_ scope: HomeScope) -> String {
        let searching = app.homeFilter.isSearching
        let label = scope.label(searching: searching)
        guard let homeCounts else { return label }
        return homeCounts.badge(of: scope, searching: searching).map { "\(label), \($0)" } ?? label
    }

    private var homeOrderPicker: some View {
        Picker(
            "Order",
            selection: Binding(
                get: { app.homeFilter.order },
                set: { app.homeFilter.order = $0 }
            )
        ) {
            ForEach(HomeOrder.allCases, id: \.self) { order in
                Text(order.label).tag(order)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .help("Order the archived work by when it finished, or by what it still holds")
    }

    private var homeProjectMenu: some View {
        let menu = HomeProjectMenu(app.repos)

        return Menu {
            Section {
                Toggle("All projects", isOn: homeAllProjects)
            }

            if !menu.visible.isEmpty {
                Section {
                    ForEach(menu.visible) { repo in
                        Toggle(repo.name, isOn: homeProjectBinding(for: repo))
                    }
                }
            }

            if !menu.hidden.isEmpty {
                Section("Hidden") {
                    ForEach(menu.hidden) { repo in
                        Toggle(repo.name, isOn: homeProjectBinding(for: repo))
                    }
                }
            }
        } label: {
            Label(homeProjectLabel, systemImage: "folder")
                .lineLimit(1)
        }
        .help("Choose which projects Home lists")
        .accessibilityLabel("Project filter, \(homeProjectLabel)")
    }

    private var homeProjectLabel: String {
        switch app.homeFilter.projects.count {
        case 0: "All projects"
        case 1: app.repos.first { $0.id == app.homeFilter.projects.first }?.name ?? "1 project"
        default: "\(app.homeFilter.projects.count) projects"
        }
    }

    private var homeAllProjects: Binding<Bool> {
        Binding(
            get: { app.homeFilter.projects.isEmpty },
            set: { isOn in if isOn { app.homeFilter.projects = [] } }
        )
    }

    private func homeProjectBinding(for repo: Repo) -> Binding<Bool> {
        Binding(
            get: { app.homeFilter.projects.contains(repo.id) },
            set: { isOn in
                if isOn {
                    app.homeFilter.projects.insert(repo.id)
                } else {
                    app.homeFilter.projects.remove(repo.id)
                }
            }
        )
    }
}
