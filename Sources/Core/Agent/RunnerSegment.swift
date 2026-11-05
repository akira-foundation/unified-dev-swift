import Foundation
import Synchronization
import os

final class RunnerSegment: Sendable {
    private let sessionID: SessionID
    private let store: Store
    private let id: SessionSegmentID
    private let acknowledgement = Mutex(HandoffAcknowledgement())

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.akira.unifieddev",
        category: "runner-segment"
    )

    init(sessionID: SessionID, store: Store, id: SessionSegmentID) {
        self.sessionID = sessionID
        self.store = store
        self.id = id
    }

    func refuseIfRetired(stopping stop: @Sendable () -> Void) async throws {
        guard let active = try await store.activeSegment(sessionID: sessionID), active.id != id else { return }
        stop()
        throw ProviderIdleError.retired
    }

    func write(_ change: @Sendable (inout Session) -> Void) async throws {
        try await store.update(sessionID: sessionID, fromSegment: id, change)
    }

    func restartHistory() async throws {
        acknowledgement.withLock { $0.historyLost() }
        try await store.resetCursor(segmentID: id)
    }

    func processStarted() {
        acknowledgement.withLock { $0.processStarted() }
    }

    func promptSent(asSteer isSteer: Bool, carriedDelta: Bool) {
        acknowledgement.withLock { $0.promptSent(asSteer: isSteer, carriedDelta: carriedDelta) }
    }

    func confirmWhatIsOwed() async {
        if acknowledgement.withLock({ $0.owedBeforeNextTurn }) { await confirm() }
    }

    func replyArrived(_ event: AgentEvent) async {
        if acknowledgement.withLock({ $0.replyArrived(event) }) { await confirm() }
    }

    func turnEnded() async {
        if acknowledgement.withLock({ $0.turnEnded() }) { await confirm() }
    }

    private func confirm() async {
        do {
            try await store.acknowledgeHandoff(sessionID: sessionID, fromSegment: id)
        } catch {
            Self.log.error("Could not acknowledge a handoff: \(error.readableMessage, privacy: .public)")
        }
    }
}
