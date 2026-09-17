import Foundation
import Observation
import Core

@MainActor
@Observable
final class RunScriptLauncher {
    static let shared = RunScriptLauncher()

    private var asks: [WorkspaceID: (project: RepoID, notice: RunScriptAutostartNotice)] = [:]

    private(set) var dismissedIssues: Set<[String]> = []

    @ObservationIgnored private var snoozed: Set<RepoID> = []

    @ObservationIgnored private var settled: [WorkspaceID: [String]] = [:]
    @ObservationIgnored private var settling: Set<WorkspaceID> = []
    @ObservationIgnored private var resettle: Set<WorkspaceID> = []
    @ObservationIgnored private var autostarted: [WorkspaceID: Set<String>] = [:]

    private init() {}

    private var sessions: TerminalSessionStore { .shared }

    func ask(for workspaceID: WorkspaceID) -> RunScriptAutostartNotice? {
        asks[workspaceID]?.notice
    }

    func isRunning(_ tab: CenterTab) -> Bool {
        tab.runScriptID != nil && sessions.activity.state(inPane: tab.id).isRunning
    }

    func pick(_ script: RunScript, in model: WorkspaceModel) {
        Task { await start(script, in: model, bringForward: true) }
    }

    func start(_ script: RunScript, in model: WorkspaceModel, bringForward: Bool) async {
        let command = script.command.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspaceID = model.workspace.id
        CenterTabStore.shared.load(workspaceID: workspaceID)

        let tabs = CenterTabStore.shared.tabs(for: workspaceID).filter {
            $0.kind == .terminal && TerminalSplitStore.shared.panes(of: $0.id).contains($0.id)
        }
        let carrying = tabs.filter { $0.runScriptID == script.id }
        await settleReadings(of: carrying, in: model)

        switch RunScriptPick.decide(
            runScript: script.id, tabs: tabs, scriptOf: \.runScriptID, isRunning: isRunning
        ) {
        case .focus(let tab):
            if bringForward { reveal(tab, in: model) }

        case .rerun(let tab):
            guard !command.isEmpty else { return }
            if sessions.retype(command, inPane: tab.id) {
                if bringForward { reveal(tab, in: model) }
            } else {
                await open(script, command: command, in: model, bringForward: bringForward)
            }

        case .open:
            guard !command.isEmpty else { return }
            await open(script, command: command, in: model, bringForward: bringForward)
        }
    }

    private func settleReadings(of tabs: [CenterTab], in model: WorkspaceModel) async {
        guard !tabs.isEmpty else { return }
        let unforked = tabs.filter { !sessions.hasShell(paneID: $0.id) }
        if !unforked.isEmpty {
            await prepareShells(in: model)
            for tab in unforked { fork(tab, in: model) }
        }
        await sessions.activity.readNow(panes: tabs.map(\.id))
    }

    private func open(
        _ script: RunScript, command: String, in model: WorkspaceModel, bringForward: Bool
    ) async {
        let tab = CenterTabStore.shared.add(
            kind: .terminal, workspaceID: model.workspace.id, title: script.name,
            runScriptID: script.id
        )
        sessions.run(command, inPaneID: tab.id)

        if bringForward {
            WorkspaceTabsStore.shared.select(.tool(tab.id), in: model)
        } else {
            await prepareShells(in: model)
            fork(tab, in: model)
        }
    }

    private func prepareShells(in model: WorkspaceModel) async {
        sessions.useStore(model.store)
        await model.ensurePort()
    }

    private func fork(_ tab: CenterTab, in model: WorkspaceModel) {
        _ = sessions.terminal(
            for: TerminalTab(id: TerminalTabID(tab.id), workspaceID: model.workspace.id, title: tab.title),
            workspace: model.workspace,
            repo: model.repo,
            port: model.port,
            directory: tab.directory
        )
    }

    private func reveal(_ tab: CenterTab, in model: WorkspaceModel) {
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model, focusing: true)
    }

    func considerAutostart(in model: WorkspaceModel) async {
        let workspaceID = model.workspace.id
        guard !settling.contains(workspaceID) else {
            resettle.insert(workspaceID)
            return
        }
        settling.insert(workspaceID)
        defer { settling.remove(workspaceID) }
        repeat {
            resettle.remove(workspaceID)
            await settleAutostart(in: model)
        } while resettle.contains(workspaceID)
    }

    private func settleAutostart(in model: WorkspaceModel) async {
        let workspaceID = model.workspace.id
        guard let repo = model.repo, let store = model.store else { return }

        await model.reloadSettings()
        let settings = model.settings
        let signature = RunScriptAutostart.signature(of: settings.runScripts)
        guard settled[workspaceID] != signature else { return }
        asks[workspaceID] = nil
        guard RunScriptAutostart.isTimely(
            isRunningSetup: model.isRunningSetup,
            setupState: model.workspace.setupState,
            hasSetupScript: settings.setupScript != nil
        ) else { return }

        let approval = await RunScriptAutostartApproval.load(repoID: repo.id, from: store)
        let decision = RunScriptAutostart.decide(scripts: settings.runScripts, approval: approval)
        switch decision {
        case .nothing:
            settled[workspaceID] = signature
        case .run(let scripts):
            settled[workspaceID] = signature
            await autostart(scripts, in: model)
        case .ask:
            guard !snoozed.contains(repo.id) else { return }
            guard let notice = RunScriptAutostartNotice.make(project: repo.name, decision: decision)
            else { return }
            asks[workspaceID] = (repo.id, notice)
        }
    }

    func notNow(in model: WorkspaceModel) {
        guard let repoID = model.repo?.id else { return }
        snoozed.insert(repoID)
        dropAsks(of: repoID)
    }

    func allow(_ notice: RunScriptAutostartNotice, in model: WorkspaceModel) async {
        guard let repo = model.repo, let store = model.store else { return }
        let workspaceID = model.workspace.id
        dropAsks(of: repo.id)
        settled[workspaceID] = RunScriptAutostart.signature(of: notice.scripts)

        let approval = await RunScriptAutostartApproval.load(repoID: repo.id, from: store)
            ?? RunScriptAutostartApproval()
        do {
            try await approval.approving(notice.scripts).save(repoID: repo.id, to: store)
        } catch {
            Log.runScripts.error(
                "Could not save the run script approval for \(repo.name, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        await autostart(notice.scripts, in: model)
    }

    private func autostart(_ scripts: [RunScript], in model: WorkspaceModel) async {
        let workspaceID = model.workspace.id
        for script in scripts {
            let entry = RunScriptAutostart.entry(of: script)
            guard autostarted[workspaceID, default: []].insert(entry).inserted else { continue }
            await start(script, in: model, bringForward: false)
        }
    }

    private func dropAsks(of repoID: RepoID) {
        for (id, ask) in asks where ask.project == repoID { asks[id] = nil }
    }

    func dismissIssues(_ notice: SettingsIssuesNotice) {
        dismissedIssues.insert(notice.signature)
    }
}
