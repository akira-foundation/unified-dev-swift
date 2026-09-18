import SwiftUI
import Core

struct CenterColumnView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        CenterPanesView(model: model)
        .safeAreaBar(edge: .top, spacing: 0) {
            WorkspaceSettingsNotices(model: model)
        }
        .task(id: model.workspace.id) {
            openStartingPane()
            await model.onAppear()
            WorkspaceTabsStore.shared.reconcile(in: model)
            await RunScriptLauncher.shared.considerAutostart(in: model)
        }
        .onChange(of: model.settings.runScripts) { _, _ in
            Task { await RunScriptLauncher.shared.considerAutostart(in: model) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshSettings()
        }
    }

    private func openStartingPane() {
        let workspaceID = model.workspace.id
        CenterTabStore.shared.load(workspaceID: workspaceID)
        guard let opening = WorkspaceStartMode.consumeOpeningTab(workspaceID: workspaceID) else {
            return
        }
        guard opening.cliAgentKind == nil else { return }
        NewPane.open(opening.pane, in: model) { WorkspaceTabsStore.shared.select($0, in: model) }
    }
}
