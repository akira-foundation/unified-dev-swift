import Foundation

struct PersistenceTrouble: Sendable, Equatable {
    private(set) var failures = 0

    private(set) var lastSentence: String?

    private(set) var hasStopped = false

    enum Outcome: Sendable, Equatable {
        case tell(String)
        case stop
        case alreadyStopped
    }

    mutating func record(_ trouble: WorkspaceTrouble?) -> Outcome {
        guard let trouble else {
            guard !hasStopped else { return .alreadyStopped }
            hasStopped = true
            return .stop
        }
        failures += 1
        lastSentence = trouble.sentence
        return .tell(trouble.sentence)
    }
}
