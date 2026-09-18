import Foundation
import Core

extension AppModel {
    func menuBarPanelInput(
        layout: UsageLayout,
        session: KeepAwakeSession?,
        whileAgentsRun: Bool,
        at now: Date
    ) -> MenuBarPanelContent.Input {
        MenuBarPanelContent.Input(
            workspaces: workspaces,
            running: runningWorkspaceIDs,
            waiting: waitingWorkspaceIDs,
            runningAgents: workingAgentCount,
            quotas: quotas,
            accounts: accounts,
            unanswered: unansweredQuotaProviders,
            layout: layout,
            hold: KeepAwake.Hold.of(
                session: session,
                whileAgentsRun: whileAgentsRun,
                runningCount: runningAgentCount,
                at: now
            ),
            now: now
        )
    }

    func revealRunningOnHome() {
        homeFilter = HomeFilter(scope: .running)
        selection = .home
    }
}
