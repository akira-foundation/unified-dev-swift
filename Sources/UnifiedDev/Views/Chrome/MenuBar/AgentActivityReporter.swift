import SwiftUI
import Core

struct AgentActivityReporter: ViewModifier {
    let app: AppModel

    @AppStorage(DockBadge.settingKey) private var isBadgeEnabled = true

    @AppStorage(SleepPrevention.settingKey) private var preventsSleep = SleepPrevention.isOnByDefault

    func body(content: Content) -> some View {
        SystemDefaults.registerOnce()

        let running = app.runningAgentCount
        let unread = DockBadge.unreadCount(in: app.workspaces, isRunning: app.isRunning)
        let waiting = app.waitingCount

        return content
            .onChange(of: running, initial: true) { _, count in
                AgentActivity.shared.setRunningCount(count)
            }
            .onChange(of: unread, initial: true) { _, count in
                AgentActivity.shared.setUnreadCount(count)
            }
            .onChange(of: waiting, initial: true) { _, count in
                AgentActivity.shared.setWaitingCount(count)
            }
            .onChange(of: preventsSleep, initial: true) { _, isOn in
                AgentActivity.shared.setPreventsSleep(isOn)
            }
            .onAppear { KeepAwakeModel.shared.restore() }
            .onChange(of: isBadgeEnabled, initial: true) { _, enabled in
                AgentActivity.shared.setBadgeEnabled(enabled)
                AgentActivity.shared.setUnreadCount(
                    DockBadge.unreadCount(in: app.workspaces, isRunning: app.isRunning)
                )
            }
    }
}

extension View {
    func reportsAgentActivity(_ app: AppModel) -> some View {
        modifier(AgentActivityReporter(app: app))
    }
}
