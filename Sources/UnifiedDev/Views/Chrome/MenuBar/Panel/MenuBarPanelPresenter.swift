import AppKit
import SwiftUI
import Core

@MainActor
final class MenuBarPanelPresenter {
    private lazy var controller = MenuBarPanelController { [weak self] command in
        self?.perform(command)
    }

    func toggle(app: AppModel, model: UsageMenuModel, below button: NSStatusBarButton) {
        guard !controller.isOpen else {
            controller.close()
            return
        }
        Task { await app.refreshQuotas(after: QuotaPollSchedule.onDemandFloor) }
        let view = MenuBarPanelView(app: app, model: model, actions: actions(for: app)) { [weak self] height in
            self?.controller.contentHeightChanged(height)
        }
        controller.open(AnyView(view), below: button)
    }

    func close() {
        controller.close()
    }

    private func actions(for app: AppModel) -> MenuBarPanelActions {
        MenuBarPanelActions(
            openWorkspace: { [weak self] id in
                self?.close()
                MainWindow.raise()
                OpenWorkspaceNotification.post(id)
            },
            openRunning: { [weak self, weak app] in
                self?.close()
                app?.revealRunningOnHome()
                MainWindow.raise()
            },
            openSettings: { [weak self] tab in
                self?.close()
                if let tab { SettingsTabRequest.post(tab) }
                SettingsWindow.open()
            },
            retryUsage: { [weak app] in
                guard let app else { return }
                Task { await app.refreshQuotas(after: 0) }
            },
            quit: { NSApp.terminate(nil) }
        )
    }

    private func perform(_ command: MenuBarPanelKey.Command) {
        switch command {
        case .close:
            close()
        case .openSettings:
            close()
            SettingsWindow.open()
        case .quit:
            NSApp.terminate(nil)
        }
    }
}
