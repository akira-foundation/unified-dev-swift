import Foundation
import Synchronization
import os

public protocol AgentProcessing: Sendable {
    var lines: AsyncThrowingStream<String, Error> { get }
    var errorLines: AsyncStream<String> { get }
    var isRunning: Bool { get }
    var exitStatus: Int32 { get async }

    func writeLine(_ text: String)
    func closeStdin()
    func terminate()
    func kill()
}

extension StreamingProcess: AgentProcessing {}

public struct AgentLaunch: Sendable, Hashable {
    public let executable: String
    public let arguments: [String]
    public let cwd: String
    public let environment: [String: String]

    public init(executable: String, arguments: [String], cwd: String, environment: [String: String]) {
        self.executable = executable
        self.arguments = arguments
        self.cwd = cwd
        self.environment = environment
    }
}

public actor AgentRunner {
    public nonisolated let workspacePath: String
    public nonisolated let sessionID: SessionID

    private let store: Store
    private let shutdownBudget: Duration
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing
    private let sink = AgentPresentationFeed()
    private var sendsInFlight = 0
    private var wasEvicted = false
    private let handle = ProcessHandle()

    private var session: Session
    private var readTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?
    private var killTask: Task<Void, Never>?
    private var stderrTail: [String] = []
    private var launchedCommand = ""
    private let mcpConfigPath: String?
    private var isFastMode = false
    private var configuredExecutable = AgentKind.claudeCode.executableName
    private var outputStyle: String?
    private var awaitingSideContextAcknowledgement = false
    private let pending = PendingAsks()

    private let grants: SessionGrants
    private var alive = false
    private var cancelled = false
    private var trouble = PersistenceTrouble()

    private var lastContextUsed = 0

    private var persistsStreamDeltas = false

    private static let stderrTailLimit = 40

    public init(
        workspacePath: String,
        session: Session,
        store: Store,
        mcpConfigPath: String? = nil,
        shutdownBudget: Duration = .seconds(5),
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = AgentRunner.spawn
    ) {
        self.workspacePath = workspacePath
        self.sessionID = session.id
        self.session = session
        self.store = store
        self.mcpConfigPath = mcpConfigPath
        self.shutdownBudget = shutdownBudget
        self.makeProcess = makeProcess
        self.grants = SessionGrants(store: store, workspaceID: session.workspaceID)
    }

    public static let spawn: @Sendable (AgentLaunch) -> any AgentProcessing = { launch in
        StreamingProcess(
            executable: launch.executable,
            arguments: launch.arguments,
            cwd: launch.cwd,
            environment: launch.environment,
            mergeStderr: false
        )
    }

    public static let executable = "claude"

    public static func argv(
        session: Session,
        resume: String?,
        isFastMode: Bool = false,
        outputStyle: String? = nil,
        mcpConfigPath: String? = nil
    ) -> [String] {
        var arguments = [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--include-partial-messages",
            "--verbose",
            "--permission-mode", session.permissionMode.cliValue,
            "--allow-dangerously-skip-permissions",
            "--permission-prompt-tool", "stdio",
            "--model", ModelAlias.cliValue(for: session.model),
        ]
        let effort = session.effort.trimmingCharacters(in: .whitespacesAndNewlines)
        if !effort.isEmpty {
            arguments += ["--effort", effort]
        }
        if isFastMode {
            arguments += ["--thinking", "disabled"]
        }
        if let settings = settingsJSON(outputStyle: outputStyle) {
            arguments += ["--settings", settings]
        }
        if let mcpConfigPath, !mcpConfigPath.isEmpty {
            arguments += BridgeRegistration.claudeArguments(configPath: mcpConfigPath)
        }
        if let resume, !resume.isEmpty {
            arguments += ["--resume", resume]
        }
        if session.workspaceID == nil {
            arguments += ["--append-system-prompt", AskConversation.instructions]
        }
        return arguments
    }

    public static func settingsJSON(outputStyle: String?) -> String? {
        guard let outputStyle, !OutputStyle.isDefault(outputStyle) else { return nil }
        let object = ["outputStyle": outputStyle.trimmingCharacters(in: .whitespacesAndNewlines)]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public func launch() -> AgentLaunch {
        AgentLaunch(
            executable: configuredExecutable,
            arguments: Self.argv(
                session: session,
                resume: session.agentSessionID,
                isFastMode: isFastMode,
                outputStyle: outputStyle,
                mcpConfigPath: mcpConfigPath
            ),
            cwd: workspacePath,
            environment: Shell.environment()
        )
    }

    public var isRunning: Bool { alive }

    public var currentSession: Session { session }

    public var lastPersistenceFailure: String? { trouble.lastSentence }

    public var persistenceFailureCount: Int { trouble.failures }

    var hasBeenCancelled: Bool { cancelled }

    public nonisolated var events: AsyncStream<AgentEvent> { sink.stream() }
    public nonisolated var presentationFeed: AgentPresentationFeed? { sink }

    public func setPersistsStreamDeltas(_ value: Bool) {
        persistsStreamDeltas = value
    }

    public func send(_ text: String, recording: Data? = nil) async throws {
        try await send(text, recording: recording, deliveryID: nil, interactionMode: nil)
    }

    public func evictIfIdle(for duration: Duration) async -> Bool {
        guard !wasEvicted, sendsInFlight == 0, !session.state.isMidTurn,
              session.agentSessionID != nil, pending.isEmpty, !sink.hasBackgroundWork else { return false }
        let lastActivity = sink.lastActivity
        guard lastActivity.duration(to: .now) >= duration,
              let waiting = try? await store.pendingDeliveries(sessionID: session.id), waiting.isEmpty else { return false }
        guard sendsInFlight == 0, !session.state.isMidTurn, pending.isEmpty,
              !sink.hasBackgroundWork, sink.lastActivity == lastActivity else { return false }
        wasEvicted = true
        terminateNow()
        return true
    }

    public func sendDelivery(_ delivery: Delivery) async throws {
        try await send(delivery.sent, recording: delivery.crewPayload,
                       deliveryID: delivery.id, interactionMode: delivery.interactionMode)
    }

    private func send(_ text: String, recording: Data?, deliveryID: DeliveryID?,
                      interactionMode: InteractionMode?) async throws {
        guard !wasEvicted else { throw ProviderIdleError.retired }
        sendsInFlight += 1
        sink.noteActivity()
        defer { sendsInFlight -= 1 }
        let prompt = try await store.sideConversationTurn(text, sessionID: sessionID)
        awaitingSideContextAcknowledgement = prompt != text
        await refreshFastMode()
        await refreshOutputStyle()
        await refreshExecutable()
        await LoginShellPath.ready()
        try await waitForCancelledRunToExit()
        start()

        let line = try Self.encodeTurn(text)
        let outgoing = try Self.encodeTurn(prompt)
        let generation = handle.generation
        guard let process = handle.current else { throw DeliveryDispatchError.processUnavailable }
        if let deliveryID { try await store.beginDeliveryDispatch(id: deliveryID) }
        guard !handle.isCancelled(generation), handle.generation == generation else { throw CancellationError() }
        process.writeLine(outgoing)
        if let deliveryID { try await store.acceptDelivery(id: deliveryID) }

        if deliveryID == nil {
            if let recording { await persist(kind: .crew, payload: recording) } else { await persist(kind: .user, payload: Data(line.utf8)) }
        }

        session.apply(.turnStarted)
        await save(session)
    }

    private func refreshFastMode() async {
        guard let value = try? await store.setting(ComposerControls.fastModeKey(sessionID: session.id)) else {
            isFastMode = false
            return
        }
        isFastMode = value == "1"
    }

    private func refreshOutputStyle() async {
        let stored = try? await store.setting(ComposerControls.outputStyleKey(sessionID: session.id))
        outputStyle = OutputStyle.isDefault(stored) ? nil : stored
    }

    private func refreshExecutable() async {
        let stored = try? await store.setting(AgentCatalog.executablePathSettingKey(.claudeCode))
        configuredExecutable = AgentCatalog.executable(for: .claudeCode, override: stored)
    }

    static func encodeTurn(_ text: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try encoder.encode(UserTurn(text: text)), as: UTF8.self)
    }

    private func waitForCancelledRunToExit() async throws {
        guard handle.isCancelledRunStillAlive else { return }

        let deadline = ContinuousClock.now + shutdownBudget
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: Self.shutdownPollInterval)
            if handle.current == nil { return }
        }
        throw AgentRunnerError.previousRunStillExiting
    }

    private static let shutdownPollInterval = Duration.milliseconds(25)

    private func start() {
        guard handle.current == nil else { return }

        cancelled = false
        stderrTail = []
        let spec = launch()
        launchedCommand = Shell.which(spec.executable) ?? spec.executable
        let process = makeProcess(spec)
        let generation = handle.beginRun(process)
        alive = true

        let errors = process.errorLines
        let lines = process.lines

        readTask = Task { [weak self] in
            await self?.consume(process, lines: lines, generation: generation)
        }
        stderrTask = Task { [weak self] in
            for await line in errors {
                await self?.appendStderr(line)
            }
        }
    }

    private func consume(
        _ process: any AgentProcessing,
        lines: AsyncThrowingStream<String, Error>,
        generation: Int
    ) async {
        var sawResult = false
        do {
            for try await line in lines {
                guard let event = AgentEvent.decode(line: line) else { continue }
                if case .result(let result) = event, !StrayResult.isStray(result) { sawResult = true }
                await ingest(event)
            }
        } catch {
            appendStderr("\(error)")
        }

        let status = await process.exitStatus
        await finish(status: status, sawResult: sawResult, generation: generation)
    }

    private func appendStderr(_ line: String) {
        stderrTail.append(line)
        if stderrTail.count > Self.stderrTailLimit {
            stderrTail.removeFirst(stderrTail.count - Self.stderrTailLimit)
        }
    }

    func ingest(_ event: AgentEvent) async {
        var event = event
        if case .permissionAsk(let ask) = event, ask.isPlanApproval {
            if let markdown = ask.input["plan"]?.stringValue {
                do {
                    _ = try await store.recordPlan(sessionID: session.id, sourceID: ask.requestID, markdown: markdown)
                } catch {
                    await report("could not save the proposed plan", error)
                }
            }
            let mode = (try? await store.planImplementationMode(
                sessionID: session.id, hasWorktree: session.workspaceID != nil
            )) ?? .acceptEdits
            event = .permissionAsk(PlanApproval.preparing(ask, mode: mode))
        }
        if case .result(let result) = event, StrayResult.isStray(result) {
            Self.log.info("ignored a result for a turn Unified Dev did not start: \(result.origin, privacy: .public)")
            await persist(kind: .system, payload: event.raw)
            return
        }

        if case .subagent(.reported(let report)) = event, !report.raw.isEmpty,
           BackgroundWake.opensTurn(during: session.state) {
            await persist(kind: .system, payload: report.raw)
        }

        var storedMessage: Message?
        if event.isTranscriptRow || persistsStreamDeltas {
            var durationMS: Int?
            if case .result(let result) = event { durationMS = result.durationMS }
            storedMessage = await persist(kind: event.kind, payload: event.raw, durationMS: durationMS, refID: event.refID)
        }

        switch event {
        case .initialized(let info):
            var moved = session.apply(.turnStarted).moves
            if !info.sessionID.isEmpty, session.agentSessionID != info.sessionID {
                session = session.with {
                    $0.agentSessionID = info.sessionID
                    $0.updatedAt = Date()
                }
                moved = true
            }
            if moved { await save(session) }

        case .assistantText(let block), .thinking(let block):
            if awaitingSideContextAcknowledgement {
                do {
                    try await store.acknowledgeSideConversationContext(sessionID: sessionID)
                    awaitingSideContextAcknowledgement = false
                } catch {
                    Self.log.error("Could not acknowledge side context: \(error.readableMessage, privacy: .public)")
                }
            }
            guard block.parentToolUseID == nil, block.usage.contextUsedTokens > 0 else { break }
            lastContextUsed = block.usage.contextUsedTokens

        case .result(let result):
            session.apply(.turnFinished(isError: result.isError))
            session = session.with {
                $0.inputTokens += result.usage.inputTokens
                $0.outputTokens += result.usage.outputTokens
                $0.costUSD += result.usage.costUSD
                if lastContextUsed > 0 { $0.contextTokens = lastContextUsed }
            }
            await save(session)

        default:
            break
        }

        sink.yield(event, messageSeq: storedMessage?.seq)

        if case .permissionAsk(let ask) = event {
            await handle(ask)
        }
    }

    @discardableResult
    private func persist(kind: MessageKind, payload: Data, durationMS: Int? = nil, refID: String? = nil) async -> Message? {
        do {
            return try await store.appendNext(
                sessionID: session.id,
                kind: kind,
                payload: payload,
                durationMS: durationMS,
                refID: refID
            )
        } catch {
            await report("could not store a \(kind.rawValue) row", error)
            return nil
        }
    }

    private func save(_ session: Session) async {
        do {
            try await store.update(sessionID: session.id) {
                $0.agentSessionID = session.agentSessionID
                $0.state = session.state
                $0.inputTokens = session.inputTokens
                $0.outputTokens = session.outputTokens
                $0.costUSD = session.costUSD
                $0.contextTokens = session.contextTokens
                $0.updatedAt = session.updatedAt
            }
        } catch {
            await report("could not save the session", error)
        }
    }

    private func report(_ what: String, _ error: Error) async {
        Self.log.error("\(what, privacy: .public): \(error.readableMessage, privacy: .public)")

        let standing = await TranscriptStanding.of(sessionID: session.id, in: store)
        switch trouble.record(WorkspaceTrouble.recording(
            transcript: standing, complaint: TranscriptStanding.complaint(about: error)
        )) {
        case .tell(let sentence):
            sink.yield(.error(.storage(message: sentence)))
        case .stop:
            Self.log.info("the transcript for \(self.session.id.rawValue, privacy: .public) has been removed, so this run is being stopped without a word")
            cancel()
        case .alreadyStopped:
            break
        }
    }

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.akira.unifieddev",
        category: "agent-runner"
    )

    private func handle(_ ask: PermissionAsk) async {
        if BridgeToolApproval.isSelfApproved(toolName: ask.toolName) {
            await write(answerTo: ask, decision: .allow(scope: .once))
            return
        }

        pending.add(ask)
        do {
            try await store.appendPermissionAsk(sessionID: session.id, ask: ask)
        } catch {
            await report("could not store a permission question", error)
        }

        let matched = await grants.matching(ask)

        if let matched, let claimed = pending.take(ask.requestID) {
            await autoAllow(claimed, using: matched)
            return
        }

        guard matched == nil, pending.contains(ask.requestID) else { return }

        session.apply(.blocked)
        await save(session)
    }

    private func autoAllow(_ ask: PermissionAsk, using matched: [PermissionGrant]) async {
        await write(answerTo: ask, decision: .allow(scope: .project))
        await close(ask, as: PermissionAskOutcome.auto, note: PermissionGrantIndex.note(for: matched))
        await grants.recordUse(of: matched)
    }

    public func answer(requestID: String, decision: PermissionDecision) async {
        guard let ask = pending.take(requestID) else { return }

        if case .approvePlan(let mode) = decision {
            guard ask.isPlanApproval, PlanApproval.modes.contains(mode) else {
                pending.add(ask)
                return
            }
            do {
                try await store.updateSessionPreferences(id: session.id, permissionMode: mode)
                session.permissionMode = mode
            } catch {
                pending.add(ask)
                await report("could not save implementation permissions", error)
                return
            }
        }

        await write(answerTo: ask, decision: decision)
        await close(ask, as: decision.storedName, note: "")

        await grants.record(decision, from: ask)
    }

    private func write(answerTo ask: PermissionAsk, decision: PermissionDecision) async {
        guard let line = try? PermissionAnswer.encode(ask: ask, decision: decision) else { return }
        handle.current?.writeLine(line)

        guard pending.isEmpty else { return }
        guard session.apply(.unblocked).moves else { return }
        await save(session)
    }

    private func close(_ ask: PermissionAsk, as decision: String, note: String) async {
        pending.remove(ask.requestID)
        do {
            try await store.resolvePermissionAsk(id: ask.requestID, decision: decision)
        } catch {
            await report("could not record a permission decision", error)
        }
        sink.yield(.permissionDecided(PermissionResolution(
            requestID: ask.requestID,
            toolUseID: ask.toolUseID,
            decision: decision,
            note: note
        )))
    }

    public var pendingAsks: [PermissionAsk] { pending.all }

    @discardableResult
    public nonisolated func denyPendingAsks(_ message: String) -> [PermissionAsk] {
        guard let process = handle.current else { return [] }
        let denied = pending.drain()
        for ask in denied {
            guard let line = try? PermissionAnswer.encode(
                ask: ask,
                decision: .deny(message: message, endsTurn: true)
            ) else { continue }
            process.writeLine(line)
        }
        return denied
    }

    func recordDenied(_ asks: [PermissionAsk], as outcome: String) async {
        for ask in asks {
            await close(ask, as: outcome, note: "")
        }
    }

    private func finish(status: Int32, sawResult: Bool, generation: Int) async {
        guard generation == handle.generation else { return }
        sink.noteProcessEnded()

        alive = false
        handle.endRun(generation)
        killTask?.cancel()
        killTask = nil

        let stderr = stderrTask
        stderrTask = nil
        await stderr?.value

        guard generation == handle.generation else { return }

        guard !cancelled, !handle.isCancelled(generation) else {
            markCancelled()
            return
        }

        if let unfinished = UnfinishedRun.of(
            status: status,
            sawResult: sawResult,
            state: session.state,
            stderr: stderrTail.joined(separator: "\n"),
            command: launchedCommand
        ) {
            Self.log.error("""
                the agent for \(self.session.id.rawValue, privacy: .public) ended on status \
                \(status, privacy: .public) with the session \
                \(self.session.state.rawValue, privacy: .public)
                """)

            await ingest(.error(AgentError(message: unfinished.message, raw: unfinished.payload)))

            session.apply(.processFailed)
            await save(session)
            return
        }

        if session.apply(.processExited).moves {
            await save(session)
        }
    }

    public func cancel() {
        cancel(generation: handle.generation)
    }

    func cancel(generation: Int) {
        guard generation == handle.generation else { return }
        let request = handle.requestCancel(generation)

        let wasCancelled = cancelled
        markCancelled()

        guard !wasCancelled, let process = request.process ?? handle.current else { return }
        let denied = denyPendingAsks(PermissionDecision.stoppedMessage)
        if !denied.isEmpty {
            Task { [weak self] in await self?.recordDenied(denied, as: PermissionAskOutcome.stopped) }
        }
        process.closeStdin()
        process.terminate()

        killTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, process.isRunning else { return }
            process.kill()
        }
    }

    private func markCancelled() {
        guard !cancelled else { return }
        cancelled = true
        alive = false

        session.apply(.cancelled)
        Task { [weak self] in await self?.saveCurrentSession() }
    }

    private func saveCurrentSession() async {
        await save(session)
    }

    public nonisolated func cancelNow() {
        let generation = handle.generation
        let request = handle.requestCancel(generation)
        let denied = denyPendingAsks(PermissionDecision.stoppedMessage)
        if request.accepted { request.process?.terminate() }
        Task { [weak self] in
            if !denied.isEmpty {
                await self?.recordDenied(denied, as: PermissionAskOutcome.stopped)
            }
            await self?.cancel(generation: generation)
        }
    }

    private struct UserTurn: Encodable {
        struct Block: Encodable {
            let type = "text"
            let text: String
        }

        struct Body: Encodable {
            let role = "user"
            let content: [Block]
        }

        let type = "user"
        let message: Body

        init(text: String) {
            message = Body(content: [Block(text: text)])
        }
    }
}

public enum AgentRunnerError: Error, Equatable, CustomStringConvertible, Sendable {
    case previousRunStillExiting

    public var description: String {
        switch self {
        case .previousRunStillExiting:
            "The previous agent is still shutting down. Try again in a moment."
        }
    }
}

private final class ProcessHandle: Sendable {
    private struct State {
        var process: (any AgentProcessing)?
        var cancelled = false
        var run = 0
    }

    private let state = Mutex(State())

    var current: (any AgentProcessing)? { state.withLock(\.process) }

    var generation: Int { state.withLock(\.run) }

    func beginRun(_ process: any AgentProcessing) -> Int {
        state.withLock { state in
            state.run += 1
            state.cancelled = false
            state.process = process
            return state.run
        }
    }

    func endRun(_ generation: Int) {
        state.withLock { state in
            guard generation == state.run else { return }
            state.process = nil
        }
    }

    func isCancelled(_ generation: Int) -> Bool {
        state.withLock { generation == $0.run && $0.cancelled }
    }

    var isCancelledRunStillAlive: Bool {
        state.withLock { $0.process != nil && $0.cancelled }
    }

    func requestCancel(_ generation: Int) -> (accepted: Bool, process: (any AgentProcessing)?) {
        state.withLock { state -> (accepted: Bool, process: (any AgentProcessing)?) in
            guard generation == state.run else { return (false, nil) }
            let accepted = !state.cancelled
            state.cancelled = true
            return (accepted, state.process)
        }
    }
}

public extension PermissionMode {
    var cliValue: String {
        switch self {
        case .auto, .autoReview: "auto"
        case .acceptEdits: "acceptEdits"
        case .bypassPermissions: "bypassPermissions"
        case .plan: "plan"
        }
    }
}
