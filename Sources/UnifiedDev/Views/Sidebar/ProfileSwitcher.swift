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
            VStack(spacing: 0) {
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

                Divider()
                    .padding(.horizontal, SidebarMetrics.switcherEdge)
            }
        }
    }

    private func label(_ active: Profile) -> some View {
        HStack(spacing: Metrics.spacingSmall) {
            HStack(spacing: SidebarMetrics.navGap) {
                ProfileMark(symbol: active.symbol, colour: active.colour)
                    .font(.system(size: SidebarMetrics.navIconSize))
                    .frame(width: SidebarMetrics.navIconColumn)

                Text(active.name)
                    .lineLimit(1)
            }

            Spacer(minLength: Metrics.spacingSmall)

            Image(systemName: "chevron.up.chevron.down")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, SidebarMetrics.switcherEdge)
        .padding(.vertical, Metrics.spacing)
    }
}

struct ProfileSwitcherItems: View {
    var profiles: [Profile]
    var activeID: ProfileID
    var onSwitch: (ProfileID) -> Void
    var onNew: () -> Void
    var onSettings: () -> Void

    var body: some View {
        Picker(selection: selection) {
            ForEach(profiles) { profile in
                ProfileMenuLabel(profile: profile)
                    .tag(profile.id)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.inline)

        Button("New Profile\u{2026}", action: onNew)
        Button("Profile Settings\u{2026}", action: onSettings)
    }

    private var selection: Binding<ProfileID> {
        Binding(get: { activeID }, set: { onSwitch($0) })
    }
}
