import SwiftUI
import Core

/// The window toolbar.
///
/// A `ToolbarContent` type rather than a `@ToolbarContentBuilder` property on `RootView`, so the
/// toolbar takes the model as an input rather than reaching for it as ambient environment.
///
/// It is attached to the DETAIL column, never to the `NavigationSplitView`. See `RootView` for the
/// crash that taught us the difference.
///
/// ## Task 7: the Finder layout
///
/// This used to draw its own sidebar toggle and its own title beside it, on the argument that the
/// system versions were not worth what they cost. Both arguments are recorded on the two structs
/// that made them, `WindowPaneToggle` and `WindowTitleControl`, and the report on this task answers
/// each: the sidebar toggle's context menu is a cost this app now accepts, and the title's rename
/// gesture and context menu are not lost, because the sidebar row already carries both.
///
/// What is left is grouped the way Finder groups its own toolbar: one glass plate per group, and
/// a `ToolbarSpacer(.fixed)` between two groups that share a placement and would otherwise share
/// a plate. Two groups here:
///
///   1. **Ask Unified Dev's new conversation**, `.navigation` placement, leading, only while a
///      conversation is open. One action, its own plate, ahead of the system's own sidebar toggle.
///   2. **The inspector's toggle**, `.primaryAction` placement, trailing, only while a workspace is
///      selected AND the inspector is closed. This is the way back in when there is nothing else
///      to open it: once the inspector is open, the same control lives inside
///      `InspectorToolbar`'s trailing cluster instead, the way the sidebar's own system toggle
///      lives inside the sidebar rather than in this bar. See `TitleBarStrip` for what could not
///      move here as well.
///
/// The two groups need no spacer between them. `.navigation` and `.primaryAction` are different
/// AppKit regions of the bar, leading and trailing respectively, so they never share a plate to
/// begin with; a `ToolbarSpacer(.flexible)` was tried here first, on the theory that it would push
/// a `.navigation` item across to the trailing edge the way it read once in this file's own
/// history, and it does not: AppKit's own title item came back to occupy the middle of the bar in
/// this task, and a `.navigation` item stays clustered at the leading edge beside the sidebar
/// toggle regardless of how much flexible space is asked for after it.
///
/// ## Search
///
/// A third group, always present at the trailing edge: a circular glyph, in its own glass capsule,
/// that opens `SearchPanelModel` on click. It used to be `.searchable`, declared on the detail
/// column in `RootView`, and that was never a compact glyph at rest: `.searchToolbarBehavior(.minimize)`
/// is `@available(macOS, unavailable)`, so on macOS `.automatic` is the only behaviour there is,
/// and an `NSSearchToolbarItem` left to it grows to fill whatever room the bar has going spare.
/// Measured on this window: with nothing else in the trailing group (no workspace selected, so no
/// inspector toggle) the field ran to roughly a third of the toolbar's width, and it only looked
/// compact on a screen with other items to compete with it for room. That was read as an SDK
/// limitation the field could not be gotten around; it was not one. `.searchable` was never the
/// right tool for a control that only ever opens a panel that is not itself a text field bound to
/// this window's own state: every character typed into it was already being forwarded straight to
/// `SearchPanelModel` and the field cleared behind it. A plain button that opens the same panel
/// does the one thing the field was for, at a fixed size no toolbar width can widen, in the same
/// glass capsule every other icon in this bar already draws in.
struct WindowToolbar: ToolbarContent {
    let app: AppModel
    let startFreshAskConversation: () -> Void

    /// What each of Home's scope chips would show, published by `HomeView`. Nil before that view
    /// has drawn once, in which case the segmented control still works and simply carries no
    /// badge yet, the same way a chip with nothing to count carries none. See
    /// `FocusedValues.homeScopeCounts`.
    @FocusedValue(\.homeScopeCounts) private var homeCounts: HomeScopeCounts?

    var body: some ToolbarContent {
        // Home's own controls: the scope segmented control that used to be `HomeBar`'s, and the
        // project menu beside it. See `homeContent`.
        //
        // ## Task: HomeBar into the toolbar
        //
        // `HomeBar` drew a strip of its own under this toolbar, on the argument (recorded on that
        // struct before it was deleted) that Home needed a place to keep a scope switch, an order
        // picker and a project filter. Apple's own guidance answers where a scope switch belongs
        // directly: "Consider using a segmented control to help people switch views in a toolbar
        // or inspector pane." So it moved here, with the two controls that went with it.
        //
        // `.principal`, the centre placement, because these are what the layout note above this
        // struct's header calls "controlos comuns": common controls, neither the window's own
        // identity (the leading edge) nor an action that opens something (the trailing edge).
        //
        // Two groups rather than one. The scope and the order picker are one function, "which
        // slice of the list and in what order", and the order picker is a dependent control that
        // appears and disappears with one particular scope, the way a tab view's own options
        // would. The project menu is a second, independent function, "which projects", so it gets
        // its own capsule with a `ToolbarSpacer(.fixed)` between them, the way Finder separates
        // its view-mode group from its share-and-label group. That keeps this screen to two
        // groups, and with the trailing search button counted, three in the bar Home draws, which
        // is the ceiling the toolbar guidance asks for.
        //
        // The query chip did NOT come here. It named an active search, not a control, and Apple's
        // toolbar guidance has nothing to say about a removable token: it went to the list's own
        // header instead. See `HomeView.queryHeader`.
        if app.selection == .home {
            ToolbarItemGroup(placement: .principal) {
                homeScopePicker

                if HomeOrder.applies(scope: app.homeFilter.scope, searching: app.homeFilter.isSearching) {
                    homeOrderPicker
                }
            }

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

        // `.primaryAction` is the trailing group, on its own without needing a flexible spacer
        // to reach that edge: `.navigation` items stay clustered at the leading edge next to the
        // sidebar toggle regardless of a spacer between them, which a `.navigation` toggle here
        // learned the hard way once AppKit's own title item came back to occupy the middle of the
        // bar.
        // Which projects, next to the control that searches them, rather than adrift in the
        // centre with the width of the window between the two. One trailing cluster: narrow the
        // list, then find in it.
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
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Search workspaces, transcripts and commands")
            .accessibilityLabel("Search workspaces, transcripts and commands")
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)

        // Only while there is a workspace to inspect AND the inspector is not already open: once
        // it is open, the trailing cluster of `InspectorToolbar` carries this same control, the way
        // the sidebar's own system toggle lives inside the sidebar rather than in this bar. Without
        // this gate the toolbar kept a redundant second toggle for a pane already showing its own;
        // with it removed outright the toolbar had no way to bring the inspector back once closed,
        // which is the regression this gate exists to prevent.
        if app.selectedWorkspace != nil, !app.isInspectorVisible {
            ToolbarItem(placement: .primaryAction) {
                WindowPaneToggle(
                    edge: .trailing,
                    isVisible: app.isInspectorVisible
                ) {
                    app.isInspectorVisible.toggle()
                }
            }
        }
    }

    // MARK: - Home

    /// `All N` / `Archived N`, native segmented, exactly as `HomeBar` drew it.
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

    /// One native segmented title, with the number that says what choosing it would show.
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

    /// Date order or size order. Offered on the Archived scope and on no other; see
    /// `HomeOrder.applies`, asked by `body` before this is even placed in the group.
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

    /// A real menu with real toggles, exactly as `HomeBar` built it: seventeen projects is a
    /// scrolling menu for free, every row is reachable by keyboard and by Voice Control, and the
    /// checkmarks are AppKit's rather than a column of drawn ticks kept in step by hand.
    ///
    /// `.menuStyle(.button)` because a borderless `Menu` on macOS throws a custom label away and
    /// draws only the chevron.
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
        .menuStyle(.button)
        .help("Choose which projects Home lists")
        .accessibilityLabel("Project filter, \(homeProjectLabel)")
    }

    /// The label says what is filtered, always. A filter you cannot see is the reason someone
    /// files a bug about workspaces having disappeared.
    private var homeProjectLabel: String {
        switch app.homeFilter.projects.count {
        case 0: "All projects"
        case 1: app.repos.first { $0.id == app.homeFilter.projects.first }?.name ?? "1 project"
        default: "\(app.homeFilter.projects.count) projects"
        }
    }

    /// Turning "All projects" on clears the set; turning it off is refused, because the state it
    /// would leave behind (nothing chosen, nothing shown, and a menu whose every row is off) has
    /// no way back that is not another click on this same row.
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
