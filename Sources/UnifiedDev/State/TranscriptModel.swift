import SwiftUI
import Observation
import Core

struct TranscriptRow: Identifiable, Hashable, Sendable {
    var id: Int64
    var seq: Int
    var kind: MessageKind
    var payload: Data
    var createdAt: Date
    var durationMS: Int?
    var refID: String?

    var resultPayload: Data?
    var isError = false
    var refusal: ToolRefusal?
    var refusalReason = ""
    var parentToolUseID: String?

    var permissionDecision: String?
    var isQuestion = false
    var permissionNote = ""

    init(message: Message) {
        id = message.id
        seq = message.seq
        kind = message.kind
        payload = message.payload
        createdAt = message.createdAt
        durationMS = message.durationMS
        refID = message.refID
    }
}

@MainActor
@Observable
final class TranscriptModel {
    private struct RunnerPreferences: Equatable {
        var model: String
        var effort: String
        var permissionMode: String
        var agentKind: String

        init(session: Session) {
            model = session.model
            effort = session.effort
            permissionMode = session.permissionMode.rawValue
            agentKind = session.agentKind.rawValue
        }
    }

    var session: Session
    let history = TranscriptHistory()
    let workspace: Workspace?
    let cwd: String
    private unowned let app: AppModel

    var home: TranscriptHome {
        TranscriptHome(workspaceID: workspace?.id, worktree: cwd)
    }

    private var workspaceNow: Workspace? {
        guard let workspace else { return nil }
        return app.existingModel(for: workspace.id)?.workspace ?? workspace
    }

    private(set) var rows: [TranscriptRow] = []
    private(set) var presentationRevision = 0
    @ObservationIgnored private var foldCache = TranscriptFoldCache()
    @ObservationIgnored private var questionIndex = PinnedQuestionIndex()
    @ObservationIgnored private var freshCalls: Set<String> = []

    func presentationFolds() -> TranscriptFold.Folds {
        let freshCalls = freshCalls
        return foldCache.resolve(rows.lazy.map { row in
            let settled: Bool
            switch row.kind {
            case .toolUse: settled = row.resultPayload != nil
            case .permissionAsk: settled = row.permissionDecision != nil
            default: settled = true
            }
            return TranscriptFold.Fact(
                seq: row.seq,
                kind: row.kind,
                failed: row.isError || row.refusal != nil,
                featured: row.isQuestion
                    || MediaShowRow.isCall(row.payload) || CodexImageViewRow.isCall(row.payload),
                drawsNothing: TranscriptNoise.isHidden(row)
                    || TranscriptRowInk.drawsNothing(kind: row.kind, payload: row.payload),
                settled: settled,
                isFresh: row.kind == .toolUse && row.refID.map(freshCalls.contains) == true,
                toolUseID: row.kind == .toolUse ? row.refID : nil,
                parentToolUseID: row.parentToolUseID,
                opensTurn: BackgroundWake.isRow(kind: row.kind, payload: row.payload)
            )
        })
    }

    func pinnedQuestion(atOrBefore seq: Int) -> PinnedQuestion? {
        questionIndex.update(session: session.id, rows: rows)
        return questionIndex.latest(atOrBefore: seq)
    }

    var isRunning: Bool { storedIsRunning }
    private var storedIsRunning = false

    var isAwaitingPermission: Bool { storedIsAwaitingPermission }
    private var storedIsAwaitingPermission = false
    private(set) var isLoaded = false

    private(set) var contextUsage: ContextWindowUsage?

    private(set) var streamingText = ""
    private(set) var streamingThinking = ""
    @ObservationIgnored private(set) var messageArrivals = MessageArrivals()
    private(set) var streamingToolName: String?
    private(set) var thinkingTokens = 0
    private(set) var statusLabel: String?

    private(set) var retryRun: RetryRun?

    private(set) var recoveredRuns: [Int: RetryRun] = [:]

    private(set) var subagents = SubagentRoster() {
        didSet {
            if let id = workspace?.id { app.noteSubagentsChanged(workspaceID: id) }
            if oldValue.isWorking != subagents.isWorking { app.noteAgentTurnsChanged() }
            let note = BackgroundWork.note(for: subagents)
            if note != backgroundWork { backgroundWork = note }
        }
    }

    private(set) var backgroundWork: String?

    var draft = ""

    private(set) var pendingDeliveries: [Delivery] = []

    private(set) var sending: Delivery?

    var waitingDeliveries: [Delivery] {
        guard let sending else { return pendingDeliveries }
        return pendingDeliveries.filter { $0.id != sending.id }
    }

    var hasNothingToShow: Bool {
        rows.isEmpty && sending == nil && pendingDeliveries.isEmpty
    }

    private var wasStoppedByHand = false
    @ObservationIgnored private var drainState = DeliveryDrainState.idle

    private var steering: Delivery?

    private var hasReportedTurnEnded = false

    private(set) var liveEndRequests = 0

    private(set) var composerFocusRequests = 0

    func appendSourceContext(_ context: String) {
        draft += (draft.isEmpty ? "" : "\n\n") + "Ask about this code:\n\n" + context + "\n\n"
        focusComposer()
    }

    func focusComposer() { composerFocusRequests += 1 }

    private var isReconcilingPresentation = false
    private var isReplayingPastTurn = false
    private var presentationMessageSeq: Int?
    private var dispatchingDeliveryID: DeliveryID?
    private var activeInteractionMode: InteractionMode?
    private var runner: (any SessionRunner)?
    @ObservationIgnored private var idleEvictionTask: Task<Void, Never>?

    func codexSubagentTranscript(for id: SubagentID) async -> SubagentTranscript? {
        guard let codex = runner as? CodexRunner else { return nil }
        return await codex.subagentTranscript(for: id)
    }
    private var pumpTask: Task<Void, Never>?
    private var runnerPreferences: RunnerPreferences?
    private var indexByRefID: [String: Int] = [:]
    private let loader = SingleFlight()
    @ObservationIgnored private var highestSeenMessageSeq = -1
    private var turnStartedAt: Date?

    init(session: Session, workspace: Workspace, app: AppModel) {
        self.session = session
        self.workspace = workspace
        self.cwd = workspace.path
        self.app = app
        history.report = { [unowned app] in app.notice = Notice(message: $0) }
    }

    init(askSession session: Session, directory: String, app: AppModel) {
        self.session = session
        self.workspace = nil
        self.cwd = directory
        self.app = app
        history.report = { [unowned app] in app.notice = Notice(message: $0) }
    }

    private var store: Store? { app.store }

    private var historyWorkspaceHeld: Bool {
        workspace.map { HistoryWorkspaceGate.shared.holds($0.id) } ?? false
    }

    private func historyBlocksSending() async -> Bool {
        if historyWorkspaceHeld { return true }
        guard let store, let workspace else { return false }
        do {
            guard let journal = try await store.pendingCheckpointRewind(workspaceID: workspace.id) else { return false }
            HistoryWorkspaceGate.shared.mark(workspace.id, unresolved: true)
            history.blockingSessionID = journal.checkpoint.sessionID
            history.failure = "Resolve the interrupted rewind in its conversation before sending more messages."
            if journal.checkpoint.sessionID == session.id { history.pendingRewind = journal }
            return true
        } catch {
            history.failure = "Could not check the workspace's rewind state: \(error)"
            return true
        }
    }

    func providerContainsTurn(_ turnID: String) async throws -> Bool {
        guard let runner = ensureRunner(), runner.supportsConversationRewind else { throw ConversationRewindError.unsupported }
        return try await runner.containsTurn(turnID)
    }

    func rewindProvider(beforeTurnID: String) async throws {
        guard let runner = ensureRunner(), runner.supportsConversationRewind else { throw ConversationRewindError.unsupported }
        try await runner.rewind(beforeTurnID: beforeTurnID)
    }

    func reloadAfterRewind() async {
        guard let store else { return }
        wasStoppedByHand = true
        sending = nil
        steering = nil
        clearStreaming()
        await read(from: store)
        await refreshSession()
        PromptAttachmentStore.shared.restoreDraftAttachments(draft, sessionID: session.id.rawValue)
        composerFocusRequests += 1
    }

    func load() async {
        guard let store, !isLoaded else {
            SwitchTrace.mark("transcript.reused", workspace: workspace?.id)
            SwitchTrace.markOnScreen("transcript.reused", workspace: workspace?.id)
            return
        }
        await loader.run { [self] in await read(from: store) }
    }

    private func read(from store: Store) async {
        SwitchTrace.mark("transcript.read.start", workspace: workspace?.id)
        let messages = (try? await store.messages(sessionID: session.id)) ?? []
        SwitchTrace.mark("transcript.read.done", workspace: workspace?.id)
        let decisions = (try? await store.permissionAskDecisions(sessionID: session.id)) ?? [:]

        let built = await Task.detached(priority: .userInitiated) {
            var rows: [TranscriptRow] = []
            var index: [String: Int] = [:]
            var highestMessageSeq = -1
            for message in messages {
                highestMessageSeq = max(highestMessageSeq, message.seq)
                Self.absorb(message, decisions: decisions, into: &rows, indexByRefID: &index)
            }
            return (rows: rows, index: index, highestMessageSeq: highestMessageSeq)
        }.value

        foldCache.reset()
        freshCalls = []
        questionIndex = PinnedQuestionIndex()
        rows = built.rows
        presentationRevision += 1
        indexByRefID = built.index
        highestSeenMessageSeq = built.highestMessageSeq

        let unread = firstUnreadSeq
        Task.detached(priority: .utility) { [rows = built.rows, worktree = cwd] in
            await TranscriptPrime.run(rows: rows, worktree: worktree, unreadSeq: unread)
        }

        contextUsage = ContextWindowUsage.latest(in: built.rows)
        SwitchTrace.mark("transcript.rows.built", workspace: workspace?.id)
        SwitchTrace.markOnScreen("transcript.rows.built", workspace: workspace?.id)

        draft = (try? await store.draft(sessionID: session.id)) ?? ""
        await refreshQueue()
        await history.load(store: store, sessionID: session.id, workspaceID: workspace?.id)
        if workspace != nil { await history.cleanupRetired(store: store, sessionID: session.id, cwd: cwd) }
        isLoaded = true
    }

    nonisolated private static func absorb(
        _ message: Message,
        decisions: [String: String],
        into rows: inout [TranscriptRow],
        indexByRefID: inout [String: Int]
    ) {
        if message.kind == .toolResult, let refID = message.refID,
           let index = indexByRefID[refID] {
            rows[index].resultPayload = message.payload
            let summary = ToolResultSummary.decode(message.payload)
            rows[index].isError = summary.isError
            rows[index].refusal = summary.refusal
            rows[index].refusalReason = summary.reason
            if let duration = message.durationMS { rows[index].durationMS = duration }
            return
        }

        var row = TranscriptRow(message: message)
        row.parentToolUseID = ParentProbe.parentToolUseID(message.payload)
        if message.kind == .permissionAsk,
           let ask = PermissionAsk.decode(payload: message.payload) {
            row.permissionDecision = decisions[ask.requestID]
            row.isQuestion = ask.isQuestion
        }
        rows.append(row)
        if message.kind == .toolUse, let refID = message.refID {
            indexByRefID[refID] = rows.count - 1
        }
    }

    nonisolated static func rows(from messages: [Message]) -> [TranscriptRow] {
        var built: [TranscriptRow] = []
        var indexByRefID: [String: Int] = [:]
        for message in messages {
            Self.absorb(message, decisions: [:], into: &built, indexByRefID: &indexByRefID)
        }
        return built
    }

    private func absorb(_ message: Message, decisions: [String: String] = [:]) {
        messageArrivals.persisted(seq: message.seq, kind: message.kind, sending: sending?.id)
        let changedIndex = message.kind == .toolResult
            ? message.refID.flatMap { indexByRefID[$0] } ?? rows.count : rows.count
        foldCache.invalidate(row: changedIndex)
        Self.absorb(message, decisions: decisions, into: &rows, indexByRefID: &indexByRefID)
        presentationRevision += 1
        if message.kind == .user { sending = nil }
    }

    var stoppedTurnSeq: Int? {
        guard session.state == .cancelled else { return nil }
        guard let index = StoppedTurn.closingRow(in: rows.lazy.map(\.kind)) else { return nil }
        return rows[index].seq
    }

    var firstUnreadSeq: Int? {
        rows.first { $0.seq > session.lastReadSeq }?.seq
    }

    func markAllRead() async {
        guard let store, let last = rows.last?.seq, last != session.lastReadSeq else { return }
        session.lastReadSeq = last
        try? await store.updateLastReadSeq(sessionID: session.id, seq: last)
    }

    func refreshSession() async {
        guard let store, let fresh = try? await store.session(id: session.id) else { return }
        session = fresh
        let isStale = turnStartedAt.map { fresh.updatedAt < $0 } ?? false
        if !isStale, fresh.state == .failed || fresh.state == .cancelled {
            setRunning(false)
            statusLabel = nil
        }
    }

    func updatePreferences(
        title: String? = nil,
        model: String? = nil,
        effort: String? = nil,
        permissionMode: PermissionMode? = nil,
        interactionMode: InteractionMode? = nil,
        implementationMode: PermissionMode? = nil,
        agentKind: AgentKind? = nil
    ) async {
        guard let store else { return }
        try? await store.updateSessionPreferences(
            id: session.id,
            title: title,
            model: model,
            effort: effort,
            permissionMode: permissionMode,
            interactionMode: interactionMode,
            implementationMode: implementationMode,
            agentKind: agentKind
        )
        await refreshSession()
    }

    func jumpToLiveEnd() {
        liveEndRequests += 1
    }

    @discardableResult
    func submit(_ text: String, clearingDraft sourceDraft: String? = nil,
                interactionMode: InteractionMode? = nil, sourcePlan: PlanArtefact? = nil) async -> Bool {
        guard !isWorkspaceArchiving else { return false }
        if usesInteractiveTerminal {
            app.alert = AppAlert(
                title: "This agent runs in a terminal",
                message: "Open its agent tab and enter the prompt in the CLI."
            )
            return false
        }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let store else { return false }

        let submittedDraft = SubmittedDraft.matching(current: draft, message: body, source: sourceDraft)
        if submittedDraft != nil { draft = "" }

        let delivery = Delivery(targetSessionID: session.id, body: body, interactionMode: interactionMode ?? session.interactionMode)
        messageArrivals.sent(delivery.id)
        if queuesNextMessage || (isRunning && delivery.interactionMode != activeInteractionMode) {
            pendingDeliveries.append(delivery)
        } else {
            sending = delivery
        }

        jumpToLiveEnd()

        do {
            _ = try await store.enqueueDelivery(delivery, clearingDraftMatching: submittedDraft, sourcePlan: sourcePlan)
        } catch {
            if sending?.id == delivery.id { sending = nil }
            pendingDeliveries.removeAll { $0.id == delivery.id }
            draft = PendingMessageReturn.draft(taking: [delivery], into: draft)
            composerFocusRequests += 1
            await saveDraft()
            Log.composer.error(
                "the message could not be queued: \(error.readableMessage, privacy: .public)"
            )
            app.alert = AppAlert(
                title: "Could not queue the message",
                message: TranscriptStanding.complaint(about: error)
            )
            return false
        }

        wasStoppedByHand = false
        await drain()
        return true
    }

    var deliveryHold: DeliveryHold {
        let model = workspace.flatMap { app.existingModel(for: $0.id) }
        return DeliveryHold.of(
            isRunningSetup: model?.isRunningSetup ?? false,
            isTurnRunning: isRunning,
            isAwaitingQuestion: isAwaitingPermission
        )
    }

    var queuesNextMessage: Bool {
        if history.isCapturing || history.isFinalisingTurn || (history.hasActiveTurn && !isRunning) || historyWorkspaceHeld { return true }
        if isRunning, session.interactionMode != activeInteractionMode { return true }
        return !Delivery.goesImmediately(
            behind: pendingDeliveries, hold: deliveryHold, on: session.agentKind
        )
    }

    var holdSentence: String? {
        if historyWorkspaceHeld { return "Resolve the interrupted rewind before sending more messages." }
        if history.isCapturing || history.isFinalisingTurn { return "Saving this turn's file changes." }
        if pendingDeliveries.first?.state == .uncertain {
            return "Unified Dev could not confirm delivery. Check the conversation before sending again."
        }
        if isRunning, let mode = pendingDeliveries.first?.interactionMode, mode != activeInteractionMode {
            return "Goes when this turn ends."
        }
        return deliveryHold.sentence(on: session.agentKind)
    }

    func drain() async {
        guard !usesInteractiveTerminal else { return }
        guard !isReconcilingPresentation else { return }
        guard !history.isCapturing, !history.isFinalisingTurn, !(history.hasActiveTurn && !isRunning), !(await historyBlocksSending()) else { return }
        guard !isWorkspaceArchiving, !wasStoppedByHand, store != nil else { return }
        guard drainState.begin() else { return }
        var allowRepeat = true
        defer { finishDrain(allowRepeat: allowRepeat) }
        await refreshQueue()

        for next in Delivery.deliverable(
            from: pendingDeliveries, hold: deliveryHold, on: session.agentKind
        ) {
            guard !isWorkspaceArchiving, !wasStoppedByHand,
                  deliveryHold.allowsDelivery(on: session.agentKind) else { return }
            if isRunning, let mode = next.interactionMode, mode != activeInteractionMode { return }
            guard pendingDeliveries.contains(where: { $0.id == next.id }) else { continue }

            sending = next

            guard await claimForDelivery(next) else {
                allowRepeat = false
                return
            }

            guard await deliver(next) else {
                allowRepeat = false
                return
            }
        }
    }

    private func finishDrain(allowRepeat: Bool) {
        let again = drainState.finish(allowRepeat: allowRepeat)
        if again, !wasStoppedByHand, !isWorkspaceArchiving {
            Task { await drain() }
        }
    }

    private func claimForDelivery(_ delivery: Delivery) async -> Bool {
        guard let store else { return false }
        do {
            let claimed = try await store.claimDelivery(id: delivery.id)
            guard claimed else {
                if sending?.id == delivery.id { sending = nil }
                await refreshQueue()
                return false
            }
            await refreshQueue()
            if isWorkspaceArchiving || wasStoppedByHand {
                try await store.restoreDelivery(id: delivery.id)
                if sending?.id == delivery.id { sending = nil }
                await refreshQueue()
                return false
            }
            return true
        } catch {
            if sending?.id == delivery.id { sending = nil }
            app.alert = AppAlert(
                title: "Could not send the message",
                message: TranscriptStanding.complaint(about: error)
            )
            return false
        }
    }

    func canRetry(_ delivery: Delivery) -> Bool {
        pendingDeliveries.first?.id == delivery.id
            && dispatchingDeliveryID != delivery.id && drainState == .idle
            && deliveryHold.allowsDelivery(on: session.agentKind)
    }

    func retryPending() async {
        guard let candidate = pendingDeliveries.first, canRetry(candidate) else { return }
        if let first = pendingDeliveries.first, first.state == .uncertain {
            do { try await store?.restoreDelivery(id: first.id) } catch { return }
            await refreshQueue()
        }
        wasStoppedByHand = false
        await drain()
    }

    var discarding: Delivery?

    func askToDiscard(_ delivery: Delivery) {
        guard dispatchingDeliveryID != delivery.id, PendingMessageDiscard.canDiscard(delivery) else { return }
        discarding = delivery
    }

    func confirmDiscard(_ delivery: Delivery) async {
        discarding = nil
        guard dispatchingDeliveryID != delivery.id else { return }
        guard let store else { return }
        let recovery = PendingMessageDiscard.recovery(of: delivery, composerDraft: draft)
        let removed = (try? await store.cancelDelivery(id: delivery.id)) ?? false
        await refreshQueue()

        guard removed else {
            app.notice = Notice(message: PendingMessageDiscard.alreadySentSentence)
            return
        }

        if delivery.crewMessage?.event == .relayed {
            await app.noteDeliveryCancelled(delivery.id)
        }

        if case .toComposer(let text) = recovery {
            draft = text
            await saveDraft()
        }
    }

    func editPending(_ delivery: Delivery) async {
        guard dispatchingDeliveryID != delivery.id, PendingMessageEdit.canEdit(delivery), let store else { return }
        let removed = (try? await store.cancelDelivery(id: delivery.id)) ?? false
        await refreshQueue()

        guard removed else {
            app.notice = Notice(message: PendingMessageEdit.alreadySentSentence)
            return
        }

        draft = PendingMessageEdit.draft(taking: delivery, into: draft)
        composerFocusRequests += 1
        jumpToLiveEnd()
        await saveDraft()
    }

    private func returnQueueToComposer() async {
        guard let store else { return }
        await refreshQueue()
        let wanted = PendingMessageReturn.returning(from: pendingDeliveries)
        guard !wanted.isEmpty else { return }

        var returned: [Delivery] = []
        for delivery in wanted {
            let left = (try? await store.cancelDelivery(id: delivery.id)) ?? false
            guard left else { continue }
            returned.append(delivery)
        }
        await refreshQueue()
        guard !returned.isEmpty else { return }

        draft = PendingMessageReturn.draft(taking: returned, into: draft)
        composerFocusRequests += 1
        await saveDraft()
    }

    func canSteer(_ delivery: Delivery) -> Bool {
        DeliverySteer.canSteer(delivery, hold: deliveryHold, on: session.agentKind)
    }

    func steer(_ delivery: Delivery) async {
        guard canSteer(delivery) else { return }
        steering = delivery
        cancelTurn()
    }

    private func sendSteered(_ delivery: Delivery) async {
        guard !isWorkspaceArchiving, !wasStoppedByHand, store != nil else { return }
        guard drainState.begin() else { return }
        var allowRepeat = true
        defer { finishDrain(allowRepeat: allowRepeat) }
        guard !isRunning else { return }

        await refreshQueue()
        guard pendingDeliveries.contains(where: { $0.id == delivery.id }) else { return }

        sending = delivery
        guard await claimForDelivery(delivery) else {
            allowRepeat = false
            return
        }
        allowRepeat = await deliver(delivery)
    }

    private func dropDiscardIfDelivered() {
        guard let discarding else { return }
        guard !pendingDeliveries.contains(where: { $0.id == discarding.id }) else { return }
        self.discarding = nil
        app.notice = Notice(message: PendingMessageDiscard.alreadySentSentence)
    }

    func refreshQueue() async {
        guard let store else { return }
        pendingDeliveries = (try? await store.pendingDeliveries(sessionID: session.id)) ?? []
        dropDiscardIfDelivered()
    }

    @discardableResult
    private func deliver(_ delivery: Delivery) async -> Bool {
        dispatchingDeliveryID = delivery.id
        defer { if dispatchingDeliveryID == delivery.id { dispatchingDeliveryID = nil } }
        guard !isWorkspaceArchiving else {
            await abandon(delivery, saying: "The workspace is being archived.")
            return false
        }
        guard let runner = ensureRunner() else {
            await abandon(delivery, saying: "Unified Dev could not open an agent for this chat.")
            return false
        }
        guard !historyWorkspaceHeld else {
            await abandon(delivery, saying: "Resolve the interrupted rewind before sending more messages.")
            return false
        }
        wasStoppedByHand = false

        let startsATurn = !isRunning
        if startsATurn {
            activeInteractionMode = delivery.interactionMode ?? session.interactionMode
            turnStartedAt = Date()
            hasReportedTurnEnded = false
            subagents.turnStarted()
            setRunning(true)
            statusLabel = "Starting"
            if let store, workspace != nil { await history.begin(delivery: delivery, store: store, cwd: cwd) }
            guard !wasStoppedByHand else {
                await abandon(delivery, saying: "Stopped before the message was sent.")
                if let store { await history.finish(store: store, cwd: cwd, endSeq: highestSeenMessageSeq) }
                return false
            }
        }

        do {
            try await runner.sendDelivery(delivery)
            if startsATurn, let store { await history.sent(delivery: delivery, store: store) }
            await appendLatestMessages()
            return true
        } catch ProviderIdleError.retired {
            if self.runner === runner {
                pumpTask?.cancel()
                pumpTask = nil
                self.runner = nil
                runnerPreferences = nil
            }
            return await deliver(delivery)
        } catch {
            if startsATurn {
                if let store { await history.finish(store: store, cwd: cwd, endSeq: highestSeenMessageSeq) }
                setRunning(false)
                statusLabel = nil
            }
            await abandon(delivery, saying: error.readableMessage)
            return false
        }
    }

    private func abandon(_ delivery: Delivery, saying complaint: String) async {
        sending = nil

        Log.composer.error(
            "the agent would not start, so the prompt stayed in the queue: \(complaint, privacy: .public)"
        )

        guard let store else {
            app.alert = AppAlert(title: "Could not start the agent", message: complaint)
            return
        }

        try? await store.releaseDeliveryClaim(id: delivery.id)
        await refreshQueue()

        let row = AgentError.notStarted(message: complaint)
        _ = try? await store.appendNext(sessionID: session.id, kind: .error, payload: row.raw)
        await appendLatestMessages()
    }

    func saveDraft() async {
        guard let store else { return }
        try? await store.saveDraft(sessionID: session.id, body: draft)
    }

    private func noteTheAgentStartedItsOwnTurn() {
        turnStartedAt = Date()
        wasStoppedByHand = false
        hasReportedTurnEnded = false
        subagents.turnStarted()
        setRunning(true)
    }

    private func setRunning(_ value: Bool) {
        if !value { setAwaitingPermission(false) }

        guard storedIsRunning != value else { return }
        storedIsRunning = value
        app.noteAgentTurnsChanged()
    }

    private func setAwaitingPermission(_ value: Bool) {
        guard storedIsAwaitingPermission != value else { return }
        storedIsAwaitingPermission = value
        app.noteAgentTurnsChanged()
    }

    private func refreshAwaitingPermission() {
        setAwaitingPermission(!pendingPermissionAsks.isEmpty)
    }

    func stop() {
        steering = nil
        cancelTurn()

        Task { await returnQueueToComposer() }
    }

    private func cancelTurn() {
        wasStoppedByHand = true
        runner?.cancelNow()
        setRunning(false)
        statusLabel = nil
        clearStreaming()
    }

    func terminateNow() {
        cancelTurn()
        steering = nil
        runner?.terminateNow()
    }

    func teardown() {
        idleEvictionTask?.cancel()
        idleEvictionTask = nil
        terminateNow()
        pumpTask?.cancel()
        pumpTask = nil
    }

    func shutdown() async {
        idleEvictionTask?.cancel()
        idleEvictionTask = nil
        guard let runner else { return }
        terminateNow()

        let deadline = ContinuousClock.now.advanced(by: .seconds(3.5))
        while ContinuousClock.now < deadline {
            let alive = await runner.isProcessAlive
            if !alive { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private var isWorkspaceArchiving: Bool {
        workspace.map { app.isArchiving($0.id) } ?? false
    }

    private func ensureRunner() -> (any SessionRunner)? {
        guard !usesInteractiveTerminal else { return nil }
        guard !isWorkspaceArchiving else { return nil }
        guard let store else { return nil }
        let preferences = RunnerPreferences(session: session)
        if runner != nil, runnerPreferences != preferences {
            runner?.terminateNow()
            pumpTask?.cancel()
            pumpTask = nil
            runner = nil
            runnerPreferences = nil
        }
        if let runner {
            if pumpTask == nil { startPump(on: runner) }
            return runner
        }
        let bridge = workspace.map { app.bridge?.register(session: session, workspace: $0) }
            ?? app.bridge?.register(askSession: session)
        let runner = Self.makeRunner(
            session: session,
            workspacePath: cwd,
            store: store,
            bridge: bridge
        )
        self.runner = runner
        runnerPreferences = preferences
        startIdleEviction()
        if pumpTask == nil { startPump(on: runner) }
        return runner
    }

    private var usesInteractiveTerminal: Bool {
        guard let workspaceID = session.workspaceID else { return false }
        CenterTabStore.shared.load(workspaceID: workspaceID)
        return CenterTabStore.shared.terminal(for: session.id, in: workspaceID) != nil
    }

    static func makeRunner(
        session: Session,
        workspacePath: String,
        store: Store,
        bridge: BridgeHandle? = nil
    ) -> any SessionRunner {
        switch session.agentKind {
        case .codex:
            return CodexRunner(
                workspacePath: workspacePath,
                session: session,
                store: store,
                bridge: bridge?.attachment
            )
        case .grok:
            return GrokRunner(
                workspacePath: workspacePath,
                session: session,
                store: store,
                bridge: bridge?.attachment
            )
        case .claudeCode, .cursor, .openCode:
            return AgentRunner(
                workspacePath: workspacePath,
                session: session,
                store: store,
                mcpConfigPath: bridge?.mcpConfigPath
            )
        }
    }

    private func startIdleEviction() {
        guard idleEvictionTask == nil else { return }
        idleEvictionTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                guard let self else { return }
                await evictIdleProvider()
            }
        }
    }

    private func evictIdleProvider() async {
        guard let store, let current = runner, !isRunning, !isAwaitingPermission,
              sending == nil, pendingDeliveries.isEmpty, !subagents.isAnythingRunning else { return }
        let stored = try? await store.setting(ProviderIdlePolicy.settingKey)
        guard let duration = ProviderIdlePolicy.duration(stored: stored),
              let waiting = try? await store.pendingDeliveries(sessionID: session.id), waiting.isEmpty,
              !isRunning, sending == nil else { return }
        guard await current.evictIfIdle(for: duration), runner === current else { return }
        pumpTask?.cancel()
        pumpTask = nil
        runner = nil
        runnerPreferences = nil
    }

    private func startPump(on runner: any SessionRunner) {
        if let feed = runner.presentationFeed {
            let baseline = feed.snapshot()
            let subscriber = UUID()
            let notifications = feed.notifications(id: subscriber, after: baseline.revision)
            pumpTask = Task { [weak self] in
                defer { feed.unsubscribe(subscriber) }
                var cursor = baseline.revision
                var pendingResult: AgentResult?
                if baseline.revision > 0, let recovery = baseline.recovery, let self {
                    await recoverPresentation(recovery, after: baseline.revision)
                    setRunning(session.state.isMidTurn)
                }
                for await _ in notifications {
                    guard let self, !Task.isCancelled else { return }
                    let batch = feed.read(after: cursor)
                    do {
                        if let failure = batch.failure { throw PresentationFailure(message: failure) }
                        let result = try await consumePresentation(batch, from: feed, after: cursor)
                        pendingResult = result ?? pendingResult
                        cursor = batch.revision
                        await feed.acknowledgePage(subscriber: subscriber, through: cursor)
                        let latest = feed.snapshot()
                        guard latest.revision == cursor else { continue }
                        if let event = latest.recovery?.stateEvent, case .error = event { pendingResult = nil }
                        if AgentPresentationReconciliation.permitsAutomaticDrain(
                            isCatchingUp: isReconcilingPresentation, isTurnRunning: isRunning || feed.isTurnRunning
                        ), let result = pendingResult {
                            pendingResult = nil
                            await finishPresentationTurn(result)
                        }
                    } catch {
                        runner.terminateNow()
                        await handle(.error(AgentError(message: error.localizedDescription)))
                        return
                    }
                }
            }
            return
        }
        pumpTask = Task { [weak self] in
            for await event in runner.events {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    private struct PresentationFailure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private func consumePresentation(
        _ batch: AgentPresentationBatch, from feed: AgentPresentationFeed, after cursor: UInt64
    ) async throws -> AgentResult? {
        isReconcilingPresentation = true
        defer {
            isReconcilingPresentation = false
            isReplayingPastTurn = false
            presentationMessageSeq = nil
        }
        var result: AgentResult?
        if let recovery = batch.recovery {
            var lifecycleCursor = cursor
            while true {
                let page = try await feed.lifecyclePage(after: lifecycleCursor, through: batch.revision)
                guard !page.isEmpty else { break }
                for entry in page {
                    isReplayingPastTurn = feed.hasLaterTurn(than: entry.revision)
                    presentationMessageSeq = entry.messageSeq
                    await handle(entry.event)
                    if case .result(let terminal) = entry.event { result = terminal }
                    lifecycleCursor = entry.revision
                }
            }
            await recoverPresentation(recovery, after: batch.revision)
        } else {
            for index in batch.events.indices {
                isReplayingPastTurn = feed.hasLaterTurn(than: batch.eventRevisions[index])
                presentationMessageSeq = batch.messageSequences[index]
                let event = batch.events[index]
                await handle(event)
                if case .result(let terminal) = event { result = terminal }
            }
        }
        return result
    }

    private func finishPresentationTurn(_ result: AgentResult) async {
        if let steered = steering {
            steering = nil
            wasStoppedByHand = false
            await sendSteered(steered)
        } else if !wasStoppedByHand { await drain() }
        if !isRunning {
            await reportToOrchestrator(CrewMessage.stopped(name: session.title, lastMessage: result.summary))
        }
    }

    private func recoverPresentation(_ recovery: AgentPresentationRecovery, after cursor: UInt64) async {
        await appendLatestMessages()
        await refreshSession()
        if let store {
            let decisions = (try? await store.permissionAskDecisions(sessionID: session.id)) ?? [:]
            for (id, decision) in decisions {
                settle(PermissionResolution(requestID: id, decision: decision))
            }
        }
        refreshAwaitingPermission()
        subagents = recovery.subagents
        if recovery.stateRevision > cursor, let event = recovery.stateEvent {
            await handle(event)
        }
        clearStreaming()
        streamingText = recovery.text
        streamingThinking = recovery.thinking
        streamingToolName = recovery.toolName
        thinkingTokens = recovery.thinkingTokens
        if let status = recovery.status { await handle(.status(status)) }
        if let retry = recovery.retry { absorb(retry) }
        if let quota = recovery.quota { await app.recordQuotas(AgentQuotaAdapters.quotas(fromRateLimitEvent: quota)) }
        if isAwaitingPermission { statusLabel = "Waiting on you" }
    }

    func acceptForProbe(_ event: AgentEvent) async {
        await handle(event)
    }

    private func handle(_ event: AgentEvent) async {
        switch event {
        case .initialized:
            if !isRunning { noteTheAgentStartedItsOwnTurn() }
            await refreshSession()
            statusLabel = "Working"

        case .status(let label):
            statusLabel = label.lowercased() == "requesting"
                ? "Waiting for model"
                : label.capitalizedFirst

        case .retrying(let retry):
            absorb(retry)

        case .thinkingTokens(let total):
            thinkingTokens = total

        case .streamDelta(let delta):
            switch delta {
            case .text(let chunk): buffer.text += chunk
            case .thinking(let chunk): buffer.thinking += chunk
            case .toolName(let name): streamingToolName = name
            case .toolInput: break
            case .blockFinished: break
            }
            scheduleStreamFlush()

        case .assistantText, .thinking, .toolUse, .toolResult:
            settleRetryRun()
            let runningTool = streamingToolName
            let callsBefore = freshCalls
            await appendLatestMessages()
            clearStreaming()
            if case .toolUse = event, !freshCalls.isSubset(of: callsBefore) {
                streamingToolName = runningTool
            }

        case .error(let failure):
            history.isFinalisingTurn = true
            steering = nil
            abandonRetryRun()
            clearStreaming()
            await appendLatestMessages()
            if let store { await history.finish(store: store, cwd: cwd, endSeq: presentationMessageSeq ?? highestSeenMessageSeq, captureFiles: !isReplayingPastTurn) }
            setRunning(false)
            statusLabel = nil
            subagents.agentExited()
            await refreshSession()
            app.alert = AppAlert(
                title: "The agent stopped in \(workspaceNow?.name ?? AskConversation.title)",
                message: failure.message.isEmpty ? "It exited without finishing the turn." : failure.message
            )
            if let workspaceNow {
                NotificationService.shared.agentFailed(workspace: workspaceNow, message: failure.message)
            }
            await reportToOrchestrator(
                CrewMessage.failed(name: session.title, reason: failure.message)
            )
            if let workspaceNow {
                await app.archiveIfRequested(
                    workspaceNow, endedIn: session.id, wasStopped: wasStoppedByHand
                )
            }

            history.isFinalisingTurn = false

        case .result(let result):
            history.isFinalisingTurn = true
            if result.succeeded { settleRetryRun() } else { abandonRetryRun() }
            clearStreaming()
            await appendLatestMessages()
            fileRecoveredRun()
            if let store { await history.finish(store: store, cwd: cwd, endSeq: presentationMessageSeq ?? highestSeenMessageSeq, captureFiles: !isReplayingPastTurn) }
            setRunning(false)
            statusLabel = nil
            if wasStoppedByHand { subagents.agentExited() }
            await refreshSession()
            await notifyFinished(result: result)
            history.isFinalisingTurn = false
            if !isReconcilingPresentation, let steered = steering {
                steering = nil
                wasStoppedByHand = false
                await sendSteered(steered)
            } else if !isReconcilingPresentation, !wasStoppedByHand {
                await drain()
            }
            if !isReconcilingPresentation, !isRunning {
                await reportToOrchestrator(
                    CrewMessage.stopped(name: session.title, lastMessage: result.summary)
                )
            }

        case .permissionAsk:
            clearStreaming()
            await appendLatestMessages()
            statusLabel = "Waiting on you"
            refreshAwaitingPermission()
            await refreshSession()
            if let workspaceNow {
                NotificationService.shared.agentNeedsPermission(workspace: workspaceNow)
            }

        case .permissionDecided(let resolution):
            settle(resolution)
            refreshAwaitingPermission()
            if !isAwaitingPermission {
                statusLabel = isRunning ? "Working" : nil
            }
            await refreshSession()

        case .rateLimit(let raw):
            await app.recordQuotas(AgentQuotaAdapters.quotas(fromRateLimitEvent: raw))

        case .subagent(let signal):
            subagents.apply(signal)
            if case .reported = signal, !isRunning { await appendLatestMessages() }

        case .hook, .unknown:
            break
        }
    }

    private func absorb(_ retry: AgentRetry) {
        if retryRun != nil {
            retryRun?.absorb(retry)
        } else {
            retryRun = RetryRun(retry)
        }
    }

    private func settleRetryRun() {
        guard let run = retryRun else { return }
        if settledRun == nil { settledRun = run }
        retryRun = nil
    }

    private func fileRecoveredRun() {
        guard let run = settledRun, let seq = rows.last?.seq else { return }
        recoveredRuns[seq] = run
        settledRun = nil
    }

    private var settledRun: RetryRun?

    private func abandonRetryRun() {
        retryRun = nil
        settledRun = nil
    }

    var projectName: String? {
        guard let workspace else { return nil }
        return app.repo(for: workspace)?.name ?? workspaceNow?.name
    }

    var pendingPermissionAsks: [PermissionAsk] {
        rows.compactMap { row in
            guard row.kind == .permissionAsk, row.permissionDecision == nil else { return nil }
            return PermissionAsk.decode(payload: row.payload)
        }
    }

    func answer(requestID: String, decision: PermissionDecision) async {
        if case .approvePlan = decision {
            await runner?.answer(requestID: requestID, decision: decision)
            return
        }
        settle(PermissionResolution(requestID: requestID, decision: decision.storedName))
        refreshAwaitingPermission()
        await runner?.answer(requestID: requestID, decision: decision)
    }

    private func settle(_ resolution: PermissionResolution) {
        guard let index = rows.firstIndex(where: {
            $0.kind == .permissionAsk
                && PermissionAsk.decode(payload: $0.payload)?.requestID == resolution.requestID
        }) else { return }

        foldCache.invalidate(row: index)
        rows[index].permissionDecision = resolution.decision
        if !resolution.note.isEmpty { rows[index].permissionNote = resolution.note }
        presentationRevision += 1
    }

    private func appendLatestMessages() async {
        guard let store else { return }
        await loader.wait()
        let fresh = (
            try? await store.messages(sessionID: session.id, afterSeq: highestSeenMessageSeq)
        ) ?? []
        guard !fresh.isEmpty else { return }
        let appendedFrom = rows.count
        var calls: [String] = []
        for message in fresh where message.seq > highestSeenMessageSeq {
            highestSeenMessageSeq = max(highestSeenMessageSeq, message.seq)
            if message.kind == .toolUse, let id = message.refID { calls.append(id) }
            absorb(message)
        }
        let stopsOnAQuestion = fresh.contains { $0.kind == .permissionAsk }
        if stopsOnAQuestion { endFreshCalls(Array(freshCalls)) }
        if !stopsOnAQuestion, !calls.isEmpty { beginFreshCalls(calls) }
        noteContextWindow(in: rows[min(appendedFrom, rows.count)...])
    }

    private func beginFreshCalls(_ calls: [String]) {
        freshCalls.formUnion(calls)
        Task { [weak self] in
            try? await Task.sleep(for: TranscriptFold.freshCall)
            self?.endFreshCalls(calls)
        }
    }

    private func endFreshCalls(_ calls: [String]) {
        var revealed = false
        for id in calls where freshCalls.remove(id) != nil {
            guard let index = indexByRefID[id], rows.indices.contains(index),
                  rows[index].resultPayload == nil else { continue }
            foldCache.invalidate(row: index)
            revealed = true
        }
        if revealed { presentationRevision += 1 }
    }

    private func noteContextWindow(in appended: ArraySlice<TranscriptRow>) {
        let usage = ContextWindowUsage.updated(contextUsage, with: appended)
        if usage != contextUsage { contextUsage = usage }
    }

    @ObservationIgnored private var buffer = (text: "", thinking: "")
    private var streamFlush: Task<Void, Never>?

    private static let streamFlushInterval = Duration.milliseconds(50)

    private func scheduleStreamFlush() {
        guard streamFlush == nil else { return }
        streamFlush = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.streamFlushInterval)
            guard let self else { return }
            streamFlush = nil
            flushStream()
        }
    }

    private func flushStream() {
        if !buffer.text.isEmpty {
            if streamingText.isEmpty { messageArrivals.beganStream(.assistantText) }
            streamingText += buffer.text
            buffer.text = ""
        }
        if !buffer.thinking.isEmpty {
            if streamingThinking.isEmpty { messageArrivals.beganStream(.thinking) }
            streamingThinking += buffer.thinking
            buffer.thinking = ""
        }
    }

    private func clearStreaming() {
        streamFlush?.cancel()
        streamFlush = nil
        buffer = ("", "")
        streamingText = ""
        streamingThinking = ""
        streamingToolName = nil
    }

    var isStreaming: Bool {
        !streamingText.isEmpty || !streamingThinking.isEmpty || streamingToolName != nil
    }

    private func reportToOrchestrator(_ message: CrewMessage) async {
        guard let parentID = session.parentSessionID, let store, let workspace else { return }
        guard !hasReportedTurnEnded else { return }
        hasReportedTurnEnded = true

        guard let parent = try? await store.session(id: parentID),
              parent.archivedAt == nil else { return }

        _ = try? await store.enqueueDelivery(
            Delivery(
                targetSessionID: parentID,
                sourceWorkspaceID: workspace.id,
                kind: .report,
                crew: message
            )
        )

        guard let model = app.existingModel(for: workspace.id) else { return }
        let transcript = model.transcript(for: parent)
        await transcript.refreshQueue()
        await transcript.drain()
    }

    private func notifyFinished(result: AgentResult) async {
        guard let store else { return }
        guard let workspace, let workspaceNow else { return }
        try? await store.touch(
            workspaceID: workspace.id, unread: app.selection.workspaceID != workspace.id
        )

        let model = app.model(for: workspaceNow)
        await model.onTurnFinished()

        NotificationService.shared.turnFinished(
            workspace: workspaceNow, result: result, wasCancelled: session.state == .cancelled
        )

        await app.archiveIfRequested(
            workspaceNow, endedIn: session.id, wasStopped: wasStoppedByHand
        )
    }
}

enum ParentProbe {
    static func parentToolUseID(_ payload: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            return nil
        }
        return object["parent_tool_use_id"] as? String
    }
}
