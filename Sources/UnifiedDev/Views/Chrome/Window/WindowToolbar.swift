import SwiftUI
import Core

struct WindowToolbar: ToolbarContent {
    let app: AppModel
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

        if let notesFormatting {
            NotesToolbar(context: notesFormatting)
        }

        if app.selection == .ask, app.ask.session != nil {
            ToolbarItem(placement: .navigation) {
                Button(action: startFreshAskConversation) {
                    Image(systemName: "square.and.pencil")
                }
                .help("Start a new Ask Unified Dev conversation")
                .accessibilityLabel("Start a new Ask Unified Dev conversation")
            }

            ToolbarSpacer(.fixed, placement: .navigation)
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
