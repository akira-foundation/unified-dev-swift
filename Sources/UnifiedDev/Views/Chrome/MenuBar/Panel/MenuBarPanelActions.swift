import Core

struct MenuBarPanelActions {
    let openApp: () -> Void
    let openWorkspace: (WorkspaceID) -> Void
    let openRunning: () -> Void
    let openSettings: (SettingsTab?) -> Void
    let retryUsage: () -> Void
    let quit: () -> Void
}
