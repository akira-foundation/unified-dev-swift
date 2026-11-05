import Foundation

public struct HandoffAcknowledgement: Sendable, Equatable {
    private enum Phase: Sendable {
        case idle, awaitingReply, settled
    }

    private var phase = Phase.idle

    public init() {}

    public static func applies(toSteer isSteer: Bool) -> Bool {
        !isSteer
    }

    public static func isRealReply(_ event: AgentEvent) -> Bool {
        switch event {
        case .toolUse:
            true
        case .assistantText(let block):
            !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !(JSONValue.parse(block.raw).map(TurnStopCause.noModelWrote) ?? false)
        default:
            false
        }
    }

    public var owedBeforeNextTurn: Bool {
        phase == .settled
    }

    public mutating func promptSent(asSteer isSteer: Bool, carriedDelta: Bool) {
        guard Self.applies(toSteer: isSteer) else { return }
        phase = carriedDelta ? .awaitingReply : .settled
    }

    public mutating func processStarted() {
        if phase == .awaitingReply { phase = .idle }
    }

    public mutating func replyArrived(_ event: AgentEvent) -> Bool {
        guard phase != .settled, Self.isRealReply(event) else { return false }
        defer { phase = .settled }
        return phase == .awaitingReply
    }

    public mutating func turnEnded() -> Bool {
        guard phase == .settled else { return false }
        phase = .idle
        return true
    }
}
