public enum CheckState: Sendable, Hashable {
    case queued
    case running
    case passed
    case failed
    case skipped
    case neutral

    public init(_ run: CheckRun) {
        guard let conclusion = run.conclusion?.uppercased(), !conclusion.isEmpty else {
            self = Self.fromStatus(run.status)
            return
        }
        self = switch conclusion {
        case "SUCCESS": .passed
        case "SKIPPED": .skipped
        case "NEUTRAL": .neutral
        case "IN_PROGRESS", "PENDING": .running
        case "QUEUED", "WAITING", "EXPECTED", "REQUESTED": .queued
        case "FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED",
             "STARTUP_FAILURE", "STALE": .failed
        default: .neutral
        }
    }

    private static func fromStatus(_ status: String) -> CheckState {
        switch status.uppercased() {
        case "COMPLETED": .neutral
        case "IN_PROGRESS", "PENDING": .running
        default: .queued
        }
    }

    public var symbolName: String {
        switch self {
        case .queued: "clock"
        case .running: "record.circle.fill"
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "minus.circle"
        case .neutral: "circle"
        }
    }

    public var isFilledMark: Bool {
        symbolName.hasSuffix(".fill")
    }

    public var description: String {
        switch self {
        case .queued: "Queued"
        case .running: "Running"
        case .passed: "Passed"
        case .failed: "Failed"
        case .skipped: "Skipped"
        case .neutral: "No result"
        }
    }
}
