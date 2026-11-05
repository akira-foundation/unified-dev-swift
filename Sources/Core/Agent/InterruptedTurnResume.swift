import Foundation

public enum InterruptedTurnResume {
    public static let instruction =
        "The previous turn was interrupted by the usage limit. Check the real state of the repository before repeating any action, then continue the task."

    public static let notResumedWhileAMessageWaits =
        "The interrupted task was not resumed because a message is already waiting. That message carries what the new agent missed."

    public static let notResumedWhileARequestWaits =
        "The interrupted task was not resumed because Unified Dev has a request of its own waiting. That request carries what the new agent missed."

    public static let replacedByMessage =
        "Your message replaced the automatic resume of the interrupted task."

    public static let didNotFinishInstruction =
        "The previous turn did not finish. Check the real state of the repository before repeating any action, then continue the task."

    public enum Origin: Sendable, Equatable {
        case providerSwitch
        case quotaAccount
        case accountOnly
    }

    public struct Facts: Sendable {
        public var origin: Origin
        public var cause: TurnStopCause
        public var hasOwnerTurn: Bool
        public var outcome: AgentSwitch.Outcome
        public var stopsAtStart: Int
        public var stopsNow: Int
        public var queue: [Delivery]

        public init(
            origin: Origin = .providerSwitch, cause: TurnStopCause, hasOwnerTurn: Bool, outcome: AgentSwitch.Outcome,
            stopsAtStart: Int, stopsNow: Int, queue: [Delivery]
        ) {
            self.origin = origin
            self.cause = cause
            self.hasOwnerTurn = hasOwnerTurn
            self.outcome = outcome
            self.stopsAtStart = stopsAtStart
            self.stopsNow = stopsNow
            self.queue = queue
        }
    }

    public enum Decision: Sendable, Equatable {
        case queue(String)
        case skip
        case tell(String)
    }

    public static func applies(cause: TurnStopCause) -> Bool {
        cause == .usageLimit
    }

    public static func decide(_ facts: Facts) -> Decision {
        let instruction: String
        switch facts.origin {
        case .providerSwitch where applies(cause: facts.cause): instruction = Self.instruction
        case .quotaAccount: instruction = didNotFinishInstruction
        case .providerSwitch, .accountOnly: return .skip
        }
        guard facts.hasOwnerTurn, facts.outcome.written, facts.outcome.queueSettled,
              facts.stopsAtStart == facts.stopsNow else { return .skip }
        guard !facts.queue.contains(where: isResume) else { return .skip }
        guard !facts.queue.isEmpty else { return .queue(instruction) }
        return .tell(facts.queue.allSatisfy(AppRequest.isHidden) ? notResumedWhileARequestWaits : notResumedWhileAMessageWaits)
    }

    public static func isResume(_ delivery: Delivery) -> Bool {
        delivery.kind == .interruptedTurnResume
    }

    public static func delivery(for sessionID: SessionID, instruction: String = instruction) -> Delivery {
        Delivery(targetSessionID: sessionID, kind: .interruptedTurnResume, body: instruction)
    }

    public static func told(_ sentence: String, after existing: String?) -> String {
        [existing, sentence].compactMap { $0 }.joined(separator: " ")
    }

    public static func shouldDropWaiting(in queue: [Delivery], markedAt stops: Int?, now: Int) -> Bool {
        queue.contains(where: isResume) && stops != now
    }
}
