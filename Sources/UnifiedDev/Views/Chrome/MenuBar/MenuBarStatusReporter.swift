import SwiftUI
import Core

struct MenuBarStatusReporter: ViewModifier {
    let app: AppModel

    @AppStorage(MenuBarStatusItem.settingKey) private var isEnabled = MenuBarStatusItem.isOnByDefault

    func body(content: Content) -> some View {
        SystemDefaults.registerOnce()

        let unread = DockBadge.unreadCount(in: app.profileWorkspaces, isRunning: app.isRunning)
        let waiting = app.profileWaitingCount

        return content
            .onChange(of: isEnabled, initial: true) { _, enabled in
                MenuBarStatusItem.shared.setEnabled(enabled, app: app)
                MenuBarStatusItem.shared.setUnreadCount(
                    DockBadge.unreadCount(in: app.profileWorkspaces, isRunning: app.isRunning)
                )
                MenuBarStatusItem.shared.setWaitingCount(app.profileWaitingCount)
            }
            .onChange(of: unread, initial: true) { _, count in
                MenuBarStatusItem.shared.setUnreadCount(count)
            }
            .onChange(of: waiting, initial: true) { _, count in
                MenuBarStatusItem.shared.setWaitingCount(count)
            }
    }
}

extension View {
    func showsAgentsInMenuBar(_ app: AppModel) -> some View {
        modifier(MenuBarStatusReporter(app: app))
    }
}
