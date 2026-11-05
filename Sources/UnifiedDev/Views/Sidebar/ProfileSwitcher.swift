import Core
import SwiftUI

struct ProfileSwitcher: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ProfileSwitcherBody(
            profiles: app.profiles,
            activeID: app.activeProfileID,
            onSwitch: { id in Task { await app.switchProfile(to: id) } },
            onNew: { app.profileSheet = .new },
            onSettings: {
                guard let active = app.activeProfile else { return }
                app.profileSheet = .edit(active)
            }
        )
    }
}

struct ProfileSwitcherBody: View {
    var profiles: [Profile]
    var activeID: ProfileID
    var onSwitch: (ProfileID) -> Void
    var onNew: () -> Void
    var onSettings: () -> Void

    var body: some View {
        if let active = profiles.first(where: { $0.id == activeID }) {
            Menu {
                ProfileSwitcherItems(
                    profiles: profiles, activeID: activeID, onSwitch: onSwitch, onNew: onNew, onSettings: onSettings
                )
            } label: {
                label(active)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .help("Switch profile")
            .accessibilityLabel("Profile, \(active.name)")
        }
    }

    private func label(_ active: Profile) -> some View {
        HStack(spacing: Metrics.spacingSmall) {
            Label {
                Text(active.name)
                    .lineLimit(1)
            } icon: {
                ProfileMark(symbol: active.symbol, colour: active.colour)
            }

            Spacer(minLength: Metrics.spacingSmall)

            Image(systemName: "chevron.up.chevron.down")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}

struct ProfileSwitcherItems: View {
    var profiles: [Profile]
    var activeID: ProfileID
    var onSwitch: (ProfileID) -> Void
    var onNew: () -> Void
    var onSettings: () -> Void

    var body: some View {
        ForEach(profiles) { profile in
            Toggle(isOn: isActive(profile.id)) {
                ProfileMenuLabel(profile: profile)
            }
        }

        Divider()

        Button("New Profile\u{2026}", action: onNew)
        Button("Profile Settings\u{2026}", action: onSettings)
    }

    private func isActive(_ id: ProfileID) -> Binding<Bool> {
        Binding(get: { activeID == id }, set: { _ in onSwitch(id) })
    }
}
