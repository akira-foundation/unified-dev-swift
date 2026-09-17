import AppKit
import SwiftUI
import Core

struct NotificationSettingsView: View {
    @AppStorage(NotificationPreferences.enabledKey) private var isEnabled = false
    @AppStorage(DockBadge.settingKey) private var badgesUnread = true

    private let service = NotificationService.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable agent notifications", isOn: $isEnabled)
                    .disabled(service.isRequestingPermission)
                    .onChange(of: isEnabled, requestPermissionIfTurnedOn)

                if isEnabled, service.isBlockedBySystem {
                    blockedNotice
                }
            } footer: {
                Text("Notifications are muted for the workspace you are viewing while Unified Dev is active.")
                    .settingsFootnote()
            }

            Section("Notify me when") {
                ForEach(NotificationEvent.allCases, id: \.self) { event in
                    EventToggle(event: event)
                }
            }
            .disabled(!isEnabled)

            Section {
                Button("Send Test Notification", action: service.sendTestNotification)
                    .disabled(!isEnabled || service.isBlockedBySystem)
            } footer: {
                Text("Preview how a notification appears.")
                    .settingsFootnote()
            }
            Section {
                Toggle("Show unread results on the Dock icon", isOn: $badgesUnread)
            } header: {
                Text("Dock badge")
            } footer: {
                Text("Counts workspaces with unread results. Clears as you read them.")
                    .settingsFootnote()
            }
        }
        .settingsForm()
        .task { await service.refreshAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await service.refreshAuthorization() }
        }
    }

    private var blockedNotice: some View {
        HStack(spacing: Metrics.gutter) {
            Label("macOS is blocking Unified Dev's notifications", systemImage: "bell.slash.fill")
                .font(Typo.label)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Metrics.spacingSmall)

            Button("Open Notification Settings", action: service.openSystemSettings)
        }
    }

    private func requestPermissionIfTurnedOn(_ was: Bool, _ isOn: Bool) {
        guard isOn else { return }
        Task { await service.requestPermission() }
    }
}

private struct EventToggle: View {
    let event: NotificationEvent
    @AppStorage private var isOn: Bool

    init(event: NotificationEvent) {
        self.event = event
        _isOn = AppStorage(wrappedValue: true, NotificationPreferences.key(for: event))
    }

    var body: some View {
        Toggle(event.title, isOn: $isOn)
            .help(event.detail)
    }
}
