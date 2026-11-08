import Core
import SwiftUI

struct ProfileSwitcherToolbar: ToolbarContent {
    var profiles: [Profile]
    var activeID: ProfileID
    var drawsSidebar: Bool
    var sidebarWidth: CGFloat
    var onSwitch: (ProfileID) -> Void
    var onNew: () -> Void
    var onSettings: () -> Void

    var body: some ToolbarContent {
        if let active = profiles.first(where: { $0.id == activeID }) {
            ToolbarItem(placement: .automatic) {
                ProfileSwitcherMenu(
                    active: active,
                    label: .resolve(profileName: active.name, drawsSidebar: drawsSidebar, sidebarWidth: sidebarWidth),
                    items: ProfileSwitcherItems(
                        profiles: profiles, activeID: activeID, onSwitch: onSwitch, onNew: onNew, onSettings: onSettings
                    )
                )
            }
        }
    }
}

extension ProfileSwitcherToolbar {
    @MainActor
    init(app: AppModel, drawsSidebar: Bool, sidebarWidth: CGFloat) {
        self.init(
            profiles: app.profiles,
            activeID: app.activeProfileID,
            drawsSidebar: drawsSidebar,
            sidebarWidth: sidebarWidth,
            onSwitch: { id in Task { await app.switchProfile(to: id) } },
            onNew: { app.askForProfileSheet(.new) },
            onSettings: {
                guard let active = app.activeProfile else { return }
                app.askForProfileSheet(.edit(active))
            }
        )
    }
}

struct ProfileSwitcherMenu: View {
    var active: Profile
    var label: ProfileToolbarLabel
    var items: ProfileSwitcherItems

    var body: some View {
        Menu {
            items
        } label: {
            if label.menuWidth != nil {
                Label {
                    Text(active.name)
                        .lineLimit(1)
                } icon: {
                    mark
                }
            } else {
                mark
            }
        }
        .labelStyle(.titleAndIcon)
        .menuIndicator(.hidden)
        .frame(maxWidth: label.menuWidth)
        .help(label.help)
        .accessibilityLabel(label.accessibilityLabel)
    }

    @ViewBuilder
    private var mark: some View {
        if let image = ProfileMarkImage.of(symbol: active.symbol, colour: active.colour) {
            Image(nsImage: image)
                .renderingMode(.original)
                .accessibilityHidden(true)
        } else {
            ProfileMark(symbol: active.symbol, colour: active.colour)
        }
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
