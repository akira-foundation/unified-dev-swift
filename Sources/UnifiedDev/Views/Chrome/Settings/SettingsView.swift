import AppKit
import SwiftUI
import Core

@MainActor
enum AppearancePreference {
    static func apply(_ value: String) {
        NSApplication.shared.appearance = switch value {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var tab: SettingsTab? = Snapshot.requestedSettingsTab ?? .general
    @State private var defaults = AppDefaults()
    @State private var isLoaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var saveError: String?
    @State private var search = ""
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
        .searchable(text: $search, placement: .sidebar, prompt: "Search")
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

            OpenInSettingsSection()

            InstallPingSettingsSection()
            CrashReportingSettingsSection()
        }
        .settingsForm()
    }
}
