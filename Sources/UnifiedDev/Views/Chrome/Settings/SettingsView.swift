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
    @State private var navigation = SettingsNavigation(
        current: SettingsTabRequest.takePending() ?? Snapshot.requestedSettingsTab ?? SettingsTab.general
    )
    @State private var defaults = AppDefaults()
    @State private var isLoaded = false
    @State private var saveTask: Task<Void, Never>?
    @State private var saveError: String?

    var body: some View {
        SettingsWindowShell(navigation: $navigation, sections: SettingsTab.sections, searchPrompt: "Search") { _ in
            detail
        }
        .task {
            guard !isLoaded, let store = app.store else { return }
            defaults = await AppDefaults.load(from: store)
            isLoaded = true
        }
        .onReceive(NotificationCenter.default.publisher(for: SettingsTabRequest.name)) { notification in
            if let requested = SettingsTabRequest.tab(in: notification) { navigation.select(requested) }
            _ = SettingsTabRequest.takePending()
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

    @ViewBuilder
    private var pane: some View {
        switch navigation.current {
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

            UpdateSettingsSection()
            InstallPingSettingsSection()
            CrashReportingSettingsSection()
        }
        .settingsForm()
    }
}
