import AppKit
import SwiftUI
import Core

/// Shared between `UnifiedDevApp`, which applies the stored choice at launch, and the Appearance
/// pane, which owns the picker that writes it.
@MainActor
enum AppearancePreference {
    static func apply(_ value: String) {
        // `shared` rather than `NSApp`: the launch call runs in `UnifiedDevApp.init`, before SwiftUI
        // has necessarily made the application object, and `NSApp` is nil until something does.
        NSApplication.shared.appearance = switch value {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }
}

/// The settings window, in the shape macOS 26 gives its own.
///
/// `NavigationSplitView` with a source list that floats over the window, the search field at the
/// top of that list, and a real toolbar carrying the two chevrons. Nothing here draws chrome: the
/// column width, the material, the divider, the card and the shadow are the system's.
///
/// The window itself is put into full-size content with a transparent title bar, which is what
/// lets the sidebar run to the top with the traffic lights over it. That is configuration of what
/// the system draws, not drawing of ours, and it is the whole of the difference between a sidebar
/// that floats and one butted against the frame.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var tab: SettingsTab? = Snapshot.requestedSettingsTab ?? .general
    @State private var defaults = AppDefaults()
    @State private var isLoaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var saveError: String?
    @State private var search = ""
    /// Panes visited before this one, and the ones stepped back from: the pair behind the two
    /// chevrons, which is what System Settings keeps there.
    @State private var history: [SettingsTab] = []
    @State private var future: [SettingsTab] = []
    @State private var isNavigating = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle((tab ?? .general).title)
        .frame(minWidth: 780, idealWidth: 850, minHeight: 560, idealHeight: 700)
        .onChange(of: tab) { previous, _ in
            guard !isNavigating, let previous else { return }
            history.append(previous)
            future.removeAll()
        }
        .task {
            guard !isLoaded, let store = app.store else { return }
            defaults = await AppDefaults.load(from: store)
            isLoaded = true
        }
    }

    private var sidebar: some View {
        List(selection: $tab) {
            Section("Unified Dev") {
                navigationRows([.general, .appearance, .menuBar, .notifications])
            }
            Section("Agents") {
                navigationRows([.agents, .sessions, .permissions, .prompts])
            }
            Section("Terminal & connections") {
                navigationRows([.terminal, .commandLine])
            }
        }
        // Nothing else. A `List` in the sidebar column of a `NavigationSplitView` already is the
        // source list: the style, the material, the row insets, the selection and the column
        // width are all the system's. Every modifier that used to be here was one of mine trying
        // to reach a look the plain declaration gives for free.
        //
        // The split view offers a toggle for the one thing this window is, so it goes, and the
        // two chevrons take its place in the bar.
        //
        // They are a real pair of buttons rather than the empty item that stood there before. The
        // bar stops reserving its row once its last item goes, which moved the list up by ten
        // points, and an empty `Color.clear` item kept the row at a price nobody could see coming:
        // under Tahoe every toolbar item is given a glass platter, and a one point wide platter is
        // a rule. Measured at x 257, eleven points tall, `#DEDEDE` on the light ramp. Two real
        // controls keep the row and say what they are for.
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: goBack) {
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(history.isEmpty)
                .help("Back")

                Button(action: goForward) {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .disabled(future.isEmpty)
                .help("Forward")
            }
        }
        // The field System Settings keeps at the top of its own source list, and what it leaves
        // in the list is `matchesSearch`.
        .searchable(text: $search, placement: .sidebar, prompt: "Search")
        // The menu bar's "Menubar Settings…" names the pane it wants; without this the window
        // opens on whichever pane it was left on, which is not what that row promises.
        .onReceive(NotificationCenter.default.publisher(for: SettingsTabRequest.name)) { notification in
            if let requested = SettingsTabRequest.tab(in: notification) { tab = requested }
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if let saveError {
                ErrorBanner(title: "Could not save settings", message: saveError) {
                    self.saveError = nil
                }
                .padding(Metrics.inset)
            }
            pane
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var defaultsBinding: Binding<AppDefaults> {
        Binding(get: { defaults }, set: { updated in
            guard isLoaded, let store = app.store else { return }
            let previous = defaults
            defaults = updated
            // Keep rapid edits in order, even when the user switches panes before a write finishes.
            let pending = saveTask
            saveTask = Task {
                await pending?.value
                do {
                    try await updated.saveChanges(from: previous, to: store)
                    saveError = nil
                } catch {
                    saveError = error.readableMessage
                }
            }
        })
    }

    private func navigationRows(_ tabs: [SettingsTab]) -> some View {
        ForEach(tabs.filter(matchesSearch), id: \.self) { item in
            SettingsTabLabel(tab: item)
                .tag(item)
        }
    }

    /// What the search field leaves in the sidebar. An empty query leaves everything.
    private func matchesSearch(_ tab: SettingsTab) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return tab.title.localizedCaseInsensitiveContains(query)
    }

    private func goBack() {
        guard let previous = history.popLast() else { return }
        if let tab { future.append(tab) }
        isNavigating = true
        tab = previous
        isNavigating = false
    }

    private func goForward() {
        guard let next = future.popLast() else { return }
        if let tab { history.append(tab) }
        isNavigating = true
        tab = next
        isNavigating = false
    }

    @ViewBuilder
    private var pane: some View {
        switch tab ?? .general {
        case .general: GeneralSettingsView()
        case .appearance: AppearanceSettingsView()
        case .menuBar: MenuBarSettingsView(app: app)
        case .notifications: NotificationSettingsView()
        case .agents: AgentsSettingsView()
        case .sessions: ModelSettingsView(defaults: defaultsBinding).disabled(!isLoaded)
        case .permissions: ApprovalSettingsView(defaults: defaultsBinding, isReady: isLoaded)
        case .prompts: PromptSettingsView()
        case .terminal: TerminalSettingsView()
        case .commandLine: CommandLineSettingsView()
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("confirmBeforeArchiving") private var confirmBeforeArchiving = true
    @State private var namesWorkspaces = WorkspaceNamingPreferences().isEnabled

    var body: some View {
        Form {
            Section("Everyday behaviour") {
                Toggle("Confirm before archiving", isOn: $confirmBeforeArchiving)
            }

            DirectorySettingsSection()

            SleepSettingsSection()

            Section("Workspaces") {
                Toggle(isOn: $namesWorkspaces) {
                    Text("Name workspaces automatically")
                    Text("Claude uses your first message to suggest a name, without accessing your code.")
                }
                .onChange(of: namesWorkspaces) { _, value in
                    WorkspaceNamingPreferences().isEnabled = value
                }

                SettingsRow("Location") {
                    VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                        HStack(spacing: Metrics.gutter) {
                            Text((WorkspaceManager.workspacesRoot.path as NSString).abbreviatingWithTildeInPath)
                                .font(Typo.codeSmall)
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                                .help(WorkspaceManager.workspacesRoot.path)
                            Spacer(minLength: 0)
                            Button("Reveal in Finder") {
                                Reveal.inFinder(WorkspaceManager.workspacesRoot.path)
                            }
                        }
                        DisclosureGroup("Folder details") {
                            Text(WorkspacesRoot.note(for: WorkspaceManager.workspacesRoot))
                                .settingsFootnote()
                        }
                    }
                }
            }

            UpdateSettingsSection()
            InstallPingSettingsSection()
            CrashReportingSettingsSection()
        }
        .settingsForm()
    }
}
