import AppKit
import Observation
import Core

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

@MainActor
@Observable
final class AppModel {
    private(set) var store: Store?
    private(set) var manager: WorkspaceManager?
    @ObservationIgnored private(set) var bridge: BridgeServer?

    private(set) var repos: [Repo] = []
    private(set) var workspaces: [Workspace] = []
    private(set) var isLoaded = false
    private(set) var quotas: [AgentQuota] = []
    private(set) var accounts: [AgentKind: AgentAccount] = [:]

    var selection: SidebarSelection {
        get { storedSelection }
        set {
            guard newValue != storedSelection else { return }
            if let id = newValue.workspaceID, id != storedSelection.workspaceID {
                SwitchTrace.begin(workspaceID: id)
            }
            let previous = storedSelection
            let vacated = previous.workspaceID
            storedSelection = newValue
            leaveDraft(from: previous, to: newValue)
            Self.rememberSelection(newValue)
            for id in Set([vacated, newValue.workspaceID].compactMap { $0 }) {
                noteSubagentsChanged(workspaceID: id)
            }
            SwitchTrace.mark("selection.set")
            if let id = newValue.workspaceID { workspaceModels[id]?.refreshSettings() }
            guard let id = newValue.workspaceID, workspaceModels[id] == nil,
                  let workspace = workspaces.first(where: { $0.id == id }) else {
                SwitchTrace.mark("model.reused")
                return
            }
            _ = model(for: workspace)
            SwitchTrace.mark("model.created")
        }
    }

    private var storedSelection: SidebarSelection = .home

    private static let lastWorkspaceKey = "sidebar.lastWorkspaceID"

    private static func rememberSelection(_ selection: SidebarSelection) {
        guard let id = selection.workspaceID else { return }
        UserDefaults.standard.set(id.rawValue, forKey: lastWorkspaceKey)
    }

    private func restoreLastSelection() {
        guard case .home = storedSelection else { return }
        guard let id = UserDefaults.standard.string(forKey: Self.lastWorkspaceKey).map(WorkspaceID.init),
              workspaces.contains(where: { $0.id == id }) else { return }
        selection = .workspace(id)
    }

    var isInspectorVisible = FrameProbe.wantsInspector

    var alert: AppAlert?
    var notice: Notice?
    var pendingArchive: ArchiveRequest?
    var transcriptResults: [TranscriptWorkspaceMatches] = []
    var isTranscriptIndexIncomplete = false
    var pendingTranscriptTarget: TranscriptSearchTarget?

    @ObservationIgnored var transcriptSearchTask: Task<Void, Never>?
    @ObservationIgnored var transcriptBackfillTask: Task<Void, Never>?
    var homeFilter = HomeFilter(scope: .archived)
    var isCreatingWorkspace = false

    let drafts = WorkspaceDrafts()

    @ObservationIgnored var undoManager: UndoManager?

    @ObservationIgnored var workspaceModels: [WorkspaceID: WorkspaceModel] = [:]

    @ObservationIgnored private var storedAsk: AskModel?

    var ask: AskModel {
        if let storedAsk { return storedAsk }
        let model = AskModel(app: self)
        storedAsk = model
        return model
    }

    private(set) var askStatus: WorkspaceStatus?

    private var archivingWorkspaceIDs: Set<WorkspaceID> = []

    func isArchiving(_ id: WorkspaceID) -> Bool { archivingWorkspaceIDs.contains(id) }

    private var archiveBookings: [WorkspaceID: SessionID] = [:]

    func bookArchive(of id: WorkspaceID, after sessionID: SessionID) {
        archiveBookings[id] = sessionID
    }

    func takeArchiveBooking(of id: WorkspaceID, endedIn sessionID: SessionID) -> Bool {
        guard archiveBookings[id] == sessionID else { return false }
        archiveBookings[id] = nil
        return true
    }

    private(set) var pendingWorkspaces: [PendingWorkspace] = []

    func showPending(_ pending: PendingWorkspace) {
        guard !pendingWorkspaces.contains(where: { $0.id == pending.id }) else { return }
        pendingWorkspaces.append(pending)
    }

    func forgetPending(_ id: WorkspaceID) {
        pendingWorkspaces.removeAll { $0.id == id }
    }

    private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var lastDiffRefresh: [WorkspaceID: Date] = [:]

    @ObservationIgnored private var diffInvalidations = DiffRefreshInvalidations()

    @ObservationIgnored private lazy var worktreeWatcher = WorktreeWatcher { [weak self] paths in
        Task { @MainActor in self?.noteWorktreesChanged(paths) }
    }
    private var storeObservationTask: Task<Void, Never>?
    private var sessionObservationTask: Task<Void, Never>?
    private var quotaObservationTask: Task<Void, Never>?
    private var workspaceMessageObservationTask: Task<Void, Never>?

    private(set) var workspaceMessagesRevision = 0
    private var quotaPollTask: Task<Void, Never>?
    private(set) var lastQuotaAskAt: Date?
    private(set) var isAskingForQuotas = false
    private var identityTask: Task<Void, Never>?
    @ObservationIgnored var iconSearchTask: Task<Void, Never>?

    @ObservationIgnored static weak var probeInstance: AppModel?

    @MainActor
    static var probeSelectedModel: WorkspaceModel? { probeInstance?.selectedModel }

    func bootstrap() async {
        Self.probeInstance = self
        guard store == nil else { return }
        Log.launchStep("bootstrap")
        let began = Date()
        do {
            let store = try await Task.detached(priority: .userInitiated) {
                try Store(path: try Store.defaultPath())
            }.value
            Log.launchStep("store open")
            self.store = store
            ComposerModelCatalog.shared.configure(store: store)
            let manager = WorkspaceManager(store: store)
            self.manager = manager
            if let trouble = await PreviewScenarioLaunch.seed(with: manager) { alert = trouble }
            Log.launchStep("scenario seeded")
            try await store.resetRunningSessions()
            try await store.recoverDeliveryClaims()
            let abandoned = try await store.abandonPendingPermissionAsks()
            if abandoned > 0 {
                Log.permissions.info("closed \(abandoned, privacy: .public) questions left by the last launch")
            }
            try await store.recoverInterruptedSetups()
            await CenterTabStore.shared.adoptTerminalTabs(from: store)
            _ = WorkspaceTabsStore.shared
            TerminalSessionStore.shared.onAgentActivityChanged = { [weak self] in
                self?.noteAgentTurnsChanged()
            }
            TerminalSessionStore.shared.onAgentTurnFinished = { [weak self] workspaceID in
                guard let self else { return }
                try? await store.touch(workspaceID: workspaceID, unread: self.selection.workspaceID != workspaceID)
                if let model = self.existingModel(for: workspaceID) {
                    Task { await model.onTurnFinished() }
                }
            }
            TerminalSessionStore.shared.useStore(store)
            BottomPanelDefaults.forget()
            Log.launchStep("recovery done")
            bridge = makeBridge(on: store)
            Log.launchStep("bridge bound")
            await reload()
            Log.launchStep("reloaded")
            await loadDrafts()
            restoreLastSelection()
            isLoaded = true
            let blocking = Int(Date().timeIntervalSince(began) * 1000)
            Log.launch.info("window usable after \(blocking, privacy: .public)ms")
            Log.launchStep("loaded")
            DispatchQueue.main.async { Log.launchStep("loaded, next turn") }
        } catch {
            Log.launchStep("bootstrap failed")
            alert = AppAlert(
                title: "Could not open the Unified Dev database",
                message: TranscriptStanding.complaint(about: error)
            )
            isLoaded = true
        }

        identityTask = Task { await GitHubIdentity.resolve() }
        startBackgroundRefresh()
        startObservingStore()
        startObservingSessions()
        startObservingWorkspaceMessages()
        startObservingQuotas()
        startPollingQuotas()
        startOwnerRegistrationRepair()
        startProjectIconSearch()
        startTranscriptIndexBackfill()
    }

    func makeBridge(on store: Store) -> BridgeServer? {
        do {
            let server = try BridgeServer(store: store, toolbox: bridgeToolbox()) { message in
                Log.bridge.info("\(message, privacy: .public)")
            }
            try server.start()
            return server
        } catch {
            Log.bridge.error("could not start the workspace bridge: \(error.readableMessage, privacy: .public)")
            return nil
        }
    }

    private func startOwnerRegistrationRepair() {
        guard let attachment = bridge?.ownerAttachment() else { return }
        let name = BridgeRegistration.ownerServerName
        Task.detached(priority: .utility) {
            switch BridgeUserRegistrationRepair.repairIfStale(serverNamed: name, matching: attachment) {
            case .repaired(let from, let to):
                Log.bridge.info("""
                    repointed \(name, privacy: .public) in ~/.claude.json \
                    from \(from, privacy: .public) to \(to, privacy: .public)
                    """)
            case .couldNotWrite(let message):
                Log.bridge.error("could not repair the \(name, privacy: .public) entry: \(message, privacy: .public)")
            case .unchanged:
                break
            }
        }
    }

    func shutdownEverything() async {
        await flushDrafts()
        refreshTask?.cancel()
        refreshTask = nil
        worktreeWatcher.stop()
        storeObservationTask?.cancel()
        storeObservationTask = nil
        sessionObservationTask?.cancel()
        sessionObservationTask = nil
        quotaObservationTask?.cancel()
        quotaObservationTask = nil
        workspaceMessageObservationTask?.cancel()
        workspaceMessageObservationTask = nil
        quotaPollTask?.cancel()
        quotaPollTask = nil
        identityTask?.cancel()
        identityTask = nil
        iconSearchTask?.cancel()
        iconSearchTask = nil
        bridge?.stop()
        bridge = nil

        let models = Array(workspaceModels.values)
        for model in models { model.stopEverything() }
        storedAsk?.stopEverything()

        async let terminals: Void = TerminalSessionStore.shared.shutdownAll()
        for model in models { await model.shutdown() }
        await storedAsk?.shutdown()
        await terminals
    }

    func reload() async {
        guard let store else { return }
        let known = Set(workspaces.map(\.id))
        do {
            let loadedRepos = try await store.repos()
            let loadedWorkspaces = try await store.workspaces()
            let listed = WorkspaceListReconciliation.afterStoreReload(
                fresh: loadedWorkspaces, archiving: archivingWorkspaceIDs
            )
            let crew = Set(listed.map(\.id)) != known ? try await store.crewByWorkspace() : nil
            let reconciled = WorkspaceListReconciliation.afterStoreReload(
                fresh: loadedWorkspaces, archiving: archivingWorkspaceIDs
            )
            if repos != loadedRepos { repos = loadedRepos }
            if workspaces != reconciled { workspaces = reconciled }
            if !pendingWorkspaces.isEmpty {
                let landed = Set(reconciled.map(\.id))
                pendingWorkspaces.removeAll { landed.contains($0.id) }
            }
            worktreeWatcher.watch(roots: workspaces.map(\.path))
            for workspace in workspaces {
                CenterTabStore.shared.load(workspaceID: workspace.id)
                if let existing = workspaceModels[workspace.id], existing.workspace != workspace {
                    existing.workspace = workspace
                }
            }
            if let crew { applyCrew(crew) }
        } catch {
            alert = AppAlert(
                title: "Could not read workspaces",
                message: TranscriptStanding.complaint(about: error)
            )
        }
    }

    func adoptProjectIcon(_ path: String?, source: RepoIconSource, forRepoID id: RepoID) {
        guard let index = repos.firstIndex(where: { $0.id == id }) else { return }
        repos[index].iconPath = path
        repos[index].iconSource = source
    }

    func recordQuotas(_ reported: [AgentQuota]) async {
        guard let store, !reported.isEmpty else { return }
        let quotas = QuotaMerge.resolved(reported, against: self.quotas)
        try? await store.recordQuotas(quotas)
    }

    func reloadQuotas() async {
        guard let store else { return }
        let loaded = (try? await store.quotas()) ?? []
        if quotas != loaded { quotas = loaded }
    }

    func refreshQuotas(after gap: TimeInterval = QuotaPollSchedule.interval) async {
        guard store != nil,
              !isAskingForQuotas,
              QuotaPollSchedule.isDue(lastAskedAt: lastQuotaAskAt, at: Date(), after: gap)
        else { return }
        isAskingForQuotas = true
        lastQuotaAskAt = Date()
        defer { isAskingForQuotas = false }
        let report = await AgentQuotaSources.report()
        for account in report.accounts where accounts[account.provider] != account {
            accounts[account.provider] = account
        }
        await recordQuotas(report.quotas)
    }

    private func startPollingQuotas() {
        quotaPollTask?.cancel()
        quotaPollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshQuotas()
                try? await Task.sleep(for: .seconds(QuotaPollSchedule.interval))
            }
        }
    }

    private func startObservingStore() {
        guard let store else { return }
        storeObservationTask?.cancel()
        storeObservationTask = Task { [weak self] in
            for await _ in store.changes(of: [.repos, .workspaces]) {
                guard let self else { return }
                await self.reload()
            }
        }
    }

    private func startObservingSessions() {
        guard let store else { return }
        sessionObservationTask?.cancel()
        sessionObservationTask = Task { [weak self] in
            await self?.refreshAgentTurns()
            await self?.refreshCrew()
            for await _ in store.changes(of: [.sessions]) {
                guard let self else { return }
                await self.refreshAgentTurns()
                await self.refreshCrew()
            }
        }
    }

    private func startObservingWorkspaceMessages() {
        guard let store else { return }
        workspaceMessageObservationTask?.cancel()
        workspaceMessageObservationTask = Task { [weak self] in
            for await _ in store.changes(of: [.workspaceMessages]) {
                guard let self else { return }
                self.workspaceMessagesRevision += 1
            }
        }
    }

    private func startObservingQuotas() {
        guard let store else { return }
        quotaObservationTask?.cancel()
        quotaObservationTask = Task { [weak self] in
            await self?.reloadQuotas()
            for await _ in store.changes(of: [.agentQuotas]) {
                guard let self else { return }
                await self.reloadQuotas()
            }
        }
    }

    private func startBackgroundRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard let self else { return }
                guard NSApp?.isActive ?? true else { continue }
                let refreshed = await self.refreshDiffStats()
                if let selected = self.selection.workspaceID, refreshed.contains(selected) {
                    await self.refreshSelectedChangedFiles()
                }
            }
        }
    }

    private func refreshSelectedChangedFiles() async {
        guard let id = selection.workspaceID, let model = workspaceModels[id] else { return }
        guard FileManager.default.fileExists(atPath: model.workspace.path) else { return }

        await model.refreshChanges(.quiet)
    }

    private func noteWorktreesChanged(_ paths: Set<String>) {
        let changed = workspaces.filter { paths.contains($0.path) }.map(\.id)
        guard !changed.isEmpty else { return }
        diffInvalidations.record(Set(changed))
    }

    @discardableResult
    func refreshDiffStats() async -> Set<WorkspaceID> {
        guard let manager else { return [] }

        var busy = runningWorkspaceIDs
        busy.formUnion(diffInvalidations.pending)
        let due = Set(DiffRefreshSchedule.due(
            workspaces: workspaces.map(\.id),
            busy: busy,
            selected: selection.workspaceID,
            lastRefreshed: lastDiffRefresh,
            now: Date()
        ))

        let present = Set(workspaces.map(\.id))
        lastDiffRefresh = lastDiffRefresh.filter { present.contains($0.key) }
        diffInvalidations.retain(present)

        let pending = workspaces.filter {
            due.contains($0.id) && FileManager.default.fileExists(atPath: $0.path)
        }

        var refreshed: Set<WorkspaceID> = []
        await withTaskGroup(of: (WorkspaceID, UInt64, Bool).self) { group in
            var next = pending.startIndex
            var running = 0
            while next < pending.endIndex || running > 0 {
                while running < DiffRefreshSchedule.width, next < pending.endIndex {
                    let workspace = pending[next]
                    let generation = diffInvalidations.generation(for: workspace.id)
                    next = pending.index(after: next)
                    running += 1
                    group.addTask {
                        let succeeded = await Self.withTimeLimit(.seconds(5)) {
                            await manager.refreshDiffStat(workspace: workspace)
                        }
                        return (workspace.id, generation, succeeded)
                    }
                }
                guard let (id, generation, succeeded) = await group.next() else { break }
                running -= 1
                diffInvalidations.finish(id, generation: generation, succeeded: succeeded)
                if succeeded {
                    lastDiffRefresh[id] = Date()
                    refreshed.insert(id)
                }
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
            }
        }
        return refreshed
    }

    private nonisolated static func withTimeLimit(
        _ limit: Duration,
        _ work: @escaping @Sendable () async -> Bool
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await work() }
            group.addTask { try? await Task.sleep(for: limit); return false }
            let succeeded = await group.next() ?? false
            group.cancelAll()
            return succeeded
        }
    }

    func repo(for workspace: Workspace) -> Repo? {
        repos.first { $0.id == workspace.repoID }
    }

    func archivedWorkspaces() async -> [Workspace] {
        if let cachedArchived { return cachedArchived }
        guard let store, let all = try? await store.workspaces(includeArchived: true) else {
            return []
        }
        let archived = all.filter { $0.state != .active }
        cachedArchived = archived
        return archived
    }

    func invalidateArchived() {
        cachedArchived = nil
        archivedRevision &+= 1
    }

    private(set) var archivedRevision = 0

    @ObservationIgnored private var cachedArchived: [Workspace]?

    func workspaces(in repo: Repo) -> [Workspace] {
        SidebarReorder.drawn(workspaces.filter { $0.repoID == repo.id })
    }

    var selectedWorkspace: Workspace? {
        guard let id = selection.workspaceID else { return nil }
        return workspaces.first { $0.id == id }
            ?? (archivingWorkspaceIDs.contains(id) ? workspaceModels[id]?.workspace : nil)
    }

    var isInspectorPresented: Bool {
        isInspectorVisible && selectedWorkspace != nil
    }

    var selectedArchivedWorkspace: Workspace? {
        guard let id = storedSelection.archivedWorkspaceID else { return nil }
        return workspaceModels[id]?.workspace
    }

    var menuWorkspace: Workspace? {
        if let id = selection.workspaceID, isArchiving(id) { return nil }
        return selectedWorkspace ?? selectedArchivedWorkspace
    }

    @discardableResult
    func model(for workspace: Workspace) -> WorkspaceModel {
        if let existing = workspaceModels[workspace.id] {
            if existing.workspace != workspace { existing.workspace = workspace }
            return existing
        }
        let model = WorkspaceModel(workspace: workspace, app: self)
        workspaceModels[workspace.id] = model
        return model
    }

    func existingModel(for id: WorkspaceID) -> WorkspaceModel? {
        workspaceModels[id]
    }

    var selectedModel: WorkspaceModel? {
        guard let id = storedSelection.workspaceID else { return nil }
        return workspaceModels[id]
    }

    private(set) var runningWorkspaceIDs: Set<WorkspaceID> = []

    @ObservationIgnored private var storedActivity: [SessionActivity] = []

    func refreshAgentTurns() async {
        guard let store, let rows = try? await store.sessionActivity() else { return }
        storedActivity = rows
        recomputeAgentTurns()
    }

    func noteAgentTurnsChanged() {
        recomputeAgentTurns()
    }

    private func recomputeAgentTurns() {
        let terminalTurns = TerminalSessionStore.shared.agentTurns
        let live = workspaceModels.values.flatMap { $0.liveTurns }
            .filter { terminalTurns[$0.sessionID] == nil } + Array(terminalTurns.values)
        let running = AgentTurns.workspaces(.running, stored: storedActivity, live: live)
            .union(TerminalSessionStore.shared.runningWorkspaceIDs)
        let waiting = AgentTurns.workspaces(.awaitingPermission, stored: storedActivity, live: live)
        if runningWorkspaceIDs != running { runningWorkspaceIDs = running }
        if waitingWorkspaceIDs != waiting { waitingWorkspaceIDs = waiting }

        let ask: WorkspaceStatus? = if let storedAsk {
            storedAsk.isAwaitingPermission ? .awaitingPermission
                : (storedAsk.isRunning ? .running : nil)
        } else {
            nil
        }
        if askStatus != ask { askStatus = ask }
    }

    private(set) var waitingWorkspaceIDs: Set<WorkspaceID> = []

    @discardableResult
    func hideFromSidebar(_ id: WorkspaceID) -> Bool {
        guard archivingWorkspaceIDs.insert(id).inserted else { return false }
        workspaces.removeAll { $0.id == id }
        return true
    }

    func restoreToSidebar(_ workspace: Workspace) {
        if !workspaces.contains(where: { $0.id == workspace.id }) { workspaces.append(workspace) }
        stopHidingFromSidebar(workspace.id)
    }

    func stopHidingFromSidebar(_ id: WorkspaceID) {
        archivingWorkspaceIDs.remove(id)
    }

    func forgetWorkspace(_ id: WorkspaceID) {
        stopHidingFromSidebar(id)
        workspaceModels[id] = nil
        archiveBookings[id] = nil
        storedActivity.removeAll { $0.workspaceID == id }
        crewRows[id] = nil
        recomputeAgentTurns()
    }

    func isAwaitingPermission(_ workspace: Workspace) -> Bool {
        waitingWorkspaceIDs.contains(workspace.id)
    }

    private(set) var subagentRows: [WorkspaceID: [SubagentRow]] = [:]

    private(set) var subagentFailures: [WorkspaceID: Int] = [:]

    @ObservationIgnored private var subagentSweeps: [WorkspaceID: Task<Void, Never>] = [:]

    func noteSubagentsChanged(workspaceID: WorkspaceID) {
        subagentSweeps.removeValue(forKey: workspaceID)?.cancel()
        guard let roster = workspaceModels[workspaceID]?.activeSubagentRoster else {
            if subagentRows[workspaceID] != nil { subagentRows[workspaceID] = nil }
            if subagentFailures[workspaceID] != nil { subagentFailures[workspaceID] = nil }
            return
        }

        if case .subagent(workspaceID, let id) = selection, roster[id] == nil {
            selection = .workspace(workspaceID)
            return
        }

        let now = Date()
        let rows = SubagentRetention.rows(roster, now: now, opened: selection.subagentID)
        let shownRows = rows.isEmpty ? nil : rows
        if subagentRows[workspaceID] != shownRows { subagentRows[workspaceID] = shownRows }

        let failures = SubagentRetention.failureCount(roster)
        let shownFailures = failures == 0 ? nil : failures
        if subagentFailures[workspaceID] != shownFailures { subagentFailures[workspaceID] = shownFailures }

        guard let next = SubagentRetention.nextChange(roster, now: now, opened: selection.subagentID)
        else { return }
        subagentSweeps[workspaceID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.noteSubagentsChanged(workspaceID: workspaceID)
        }
    }

    func subagents(of workspaceID: WorkspaceID) -> [SubagentRow] {
        subagentRows[workspaceID] ?? []
    }

    func subagentFailures(of workspaceID: WorkspaceID) -> Int {
        subagentFailures[workspaceID] ?? 0
    }

    private(set) var crewRows: [WorkspaceID: [CrewRow]] = [:]

    func crew(of workspaceID: WorkspaceID) -> [CrewRow] {
        crewRows[workspaceID] ?? []
    }

    func refreshCrew() async {
        guard let store else { return }
        applyCrew((try? await store.crewByWorkspace()) ?? [:])
    }

    private func applyCrew(_ grouped: [WorkspaceID: [Session]]) {
        var fresh: [WorkspaceID: [CrewRow]] = [:]
        for workspace in workspaces {
            guard let members = grouped[workspace.id], !members.isEmpty else { continue }
            fresh[workspace.id] = members.map(CrewRow.init)
        }
        if crewRows != fresh { crewRows = fresh }

        if let sessionID = selection.crewSessionID, let workspaceID = selection.workspaceID,
           !crew(of: workspaceID).contains(where: { $0.id == sessionID }) {
            selection = .workspace(workspaceID)
        }
    }

    var waitingCount: Int {
        DockBadge.waitingCount(in: workspaces) { waitingWorkspaceIDs.contains($0.id) }
    }

    #if DEBUG
    func setRunningWorkspaceIDsForCapture(_ ids: Set<WorkspaceID>) {
        runningWorkspaceIDs = ids
    }
    #endif

    var runningCount: Int {
        runningWorkspaceIDs.count
    }

    func isRunning(_ workspace: Workspace) -> Bool {
        runningWorkspaceIDs.contains(workspace.id)
    }

    var runningAgentCount: Int {
        runningWorkspaceIDs.count + ((storedAsk?.isRunning ?? false) ? 1 : 0)
    }

    var runningAgentWorkspaceNames: [String] {
        let workspaceNames = runningWorkspaceIDs
            .compactMap { id in
                workspaceModels[id]?.workspace.name ?? workspaces.first { $0.id == id }?.name
            }
            .sorted()
        guard storedAsk?.isRunning == true else { return workspaceNames }
        return workspaceNames + [AskConversation.title]
    }

    var restoring: Set<WorkspaceID> = []

    var carryingOn: Set<WorkspaceID> = []

    func reorderWorkspaces(in repo: Repo, visible: [Workspace], from: IndexSet, to: Int) async {
        guard let store else { return }
        let changes = SidebarReorder.move(
            visible: visible, all: workspaces(in: repo), from: from, to: to
        )
        guard !changes.isEmpty else { return }

        let byID = Dictionary(changes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        workspaces = workspaces.map { workspace in
            guard let change = byID[workspace.id] else { return workspace }
            var moved = workspace
            moved.sortOrder = change.sortOrder
            moved.pinned = change.pinned
            return moved
        }

        try? await store.reorderWorkspaces(changes)
    }

    func reorderProjects(id: RepoID, visible: [RepoID], to: Int) async {
        guard let store else { return }
        let changes = SidebarReorder.move(projects: repos, visible: visible, id: id, to: to)
        guard !changes.isEmpty else { return }

        let byID = Dictionary(changes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        repos = repos
            .map { repo in
                guard let change = byID[repo.id] else { return repo }
                var moved = repo
                moved.sortOrder = change.sortOrder
                return moved
            }
            .sorted { $0.sortOrder < $1.sortOrder }

        try? await store.reorderProjects(changes)
    }
}
