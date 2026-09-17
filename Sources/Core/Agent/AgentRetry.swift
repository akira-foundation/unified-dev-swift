import Foundation

public struct AgentRetry: Sendable, Hashable {
    public enum Scope: Sendable, Hashable {
        case turn
        case subagent(agentID: String, toolUseID: String?, kind: String?)

        public var agentID: String? {
            if case .subagent(let id, _, _) = self { return id }
            return nil
        }
    }

    public let scope: Scope
    public let attempt: Int
    public let maxAttempts: Int
    public let delay: TimeInterval
    public let status: Int?
    public let category: String?
    public let raw: Data
    public let uuid: String?
    public let sessionID: String?

    public init(
        scope: Scope = .turn,
        attempt: Int,
        maxAttempts: Int,
        delay: TimeInterval,
        status: Int?,
        category: String? = nil,
        raw: Data = Data(),
        uuid: String? = nil,
        sessionID: String? = nil
    ) {
        self.scope = scope
        self.attempt = attempt
        self.maxAttempts = maxAttempts
        self.delay = delay
        self.status = status
        self.category = category
        self.raw = raw
        self.uuid = uuid
        self.sessionID = sessionID
    }

    public var trouble: RetryTrouble { RetryTrouble.diagnose(status: status, category: category) }

    public var patience: RetryPatience {
        RetryPatience.of(attempt: attempt, maxAttempts: maxAttempts)
    }

    public var headline: String { trouble.headline }

    public var note: String {
        "\(patience.counsel(canAct: trouble.isWorthActingOn)) \(trouble.counsel)"
    }

    public var summary: String { "\(progress) \(note)" }

    public var progress: String { "Attempt \(attempt) of \(maxAttempts)." }

    public var readout: String {
        guard maxAttempts > 0 else { return trouble.readout }
        return "\(trouble.readout) \(attempt)/\(maxAttempts)"
    }

    public var waitPhrase: String? {
        guard delay >= 5 else { return nil }
        return "Next attempt in about \(Self.coarse(delay))."
    }

    static func coarse(_ seconds: TimeInterval) -> String {
        if seconds >= 90 {
            let minutes = (seconds / 60).rounded()
            return minutes == 1 ? "a minute" : "\(Int(minutes)) minutes"
        }
        let step: Double = seconds < 20 ? 5 : 10
        let rounded = max(step, (seconds / step).rounded() * step)
        return "\(Int(rounded)) seconds"
    }

    public static func turnRetry(_ json: JSONValue, raw: Data) -> AgentRetry {
        AgentRetry(
            scope: .turn,
            attempt: json["attempt"]?.intValue ?? 1,
            maxAttempts: json["max_retries"]?.intValue ?? 0,
            delay: milliseconds(json["retry_delay_ms"]),
            status: json["error_status"]?.intValue,
            category: json["error"]?.stringValue,
            raw: raw,
            uuid: json["uuid"]?.stringValue,
            sessionID: json["session_id"]?.stringValue
        )
    }

    public static func subagentRetry(_ json: JSONValue, raw: Data) -> AgentRetry? {
        guard let block = json["subagent_retry"], let agentID = block["agent_id"]?.stringValue
        else { return nil }
        return AgentRetry(
            scope: .subagent(
                agentID: agentID,
                toolUseID: json["parent_tool_use_id"]?.stringValue ?? json["tool_use_id"]?.stringValue,
                kind: json["subagent_type"]?.stringValue
            ),
            attempt: block["attempt"]?.intValue ?? 1,
            maxAttempts: block["max_retries"]?.intValue ?? 0,
            delay: milliseconds(block["retry_delay_ms"]),
            status: block["error_status"]?.intValue,
            category: block["error_category"]?.stringValue,
            raw: raw,
            uuid: json["uuid"]?.stringValue,
            sessionID: json["session_id"]?.stringValue
        )
    }

    private static func milliseconds(_ value: JSONValue?) -> TimeInterval {
        guard let ms = value?.doubleValue, ms > 0 else { return 0 }
        return ms / 1000
    }
}

public enum RetryTrouble: Sendable, Hashable {
    case overloaded
    case rateLimited
    case serverFault(Int)
    case refused(Int)
    case unreachable
    case unexplained(Int)

    public static func diagnose(status: Int?, category: String?) -> RetryTrouble {
        guard let status else {
            switch category?.lowercased() {
            case "overloaded": return .overloaded
            case "rate_limit", "rate_limited": return .rateLimited
            default: return .unreachable
            }
        }
        switch status {
        case 529: return .overloaded
        case 429: return .rateLimited
        case 500...599: return .serverFault(status)
        case 400...499: return .refused(status)
        default: return .unexplained(status)
        }
    }

    public var headline: String {
        switch self {
        case .overloaded: "Anthropic's API is overloaded"
        case .rateLimited: "Anthropic's API is rate limiting this account"
        case .serverFault: "Anthropic's API is failing"
        case .refused: "Anthropic's API refused the request"
        case .unreachable: "Unified Dev cannot reach Anthropic's API"
        case .unexplained: "Anthropic's API returned an error"
        }
    }

    public var readout: String {
        switch self {
        case .overloaded: "overloaded"
        case .rateLimited: "rate limited"
        case .serverFault: "API failing"
        case .refused: "API refused it"
        case .unreachable: "no answer"
        case .unexplained: "API error"
        }
    }

    public var counsel: String {
        switch self {
        case .overloaded:
            return "It is capacity at their end, not anything here."
        case .rateLimited:
            return "It is this account's allowance rather than a fault. What is left of it is in "
                + "the menu bar."
        case .serverFault(let status):
            return "It is a fault at their end (\(status)), not anything here."
        case .refused(let status):
            return "It came back as \(status), which waiting does not usually clear. If every "
                + "attempt goes the same way the turn stops and says so."
        case .unreachable:
            return "Nothing came back at all, which can be this machine's network as easily as "
                + "theirs. Worth a glance at your connection."
        case .unexplained(let status):
            return "It came back as \(status), which Unified Dev has no reading of."
        }
    }

    public var isWorthActingOn: Bool {
        switch self {
        case .overloaded, .rateLimited, .serverFault: false
        case .refused, .unreachable, .unexplained: true
        }
    }
}

public enum RetryPatience: Sendable, Hashable, Comparable {
    case settling
    case persisting
    case lastChances

    public static func of(attempt: Int, maxAttempts: Int) -> RetryPatience {
        guard maxAttempts > 0 else { return .persisting }
        if attempt >= maxAttempts - 1 { return .lastChances }
        if attempt * 3 <= maxAttempts { return .settling }
        return .persisting
    }

    public func counsel(canAct: Bool) -> String {
        switch self {
        case .settling:
            return canAct
                ? "Trying again by itself."
                : "Trying again by itself, with nothing for you to do."
        case .persisting:
            return canAct
                ? "Still trying, with longer waits between attempts."
                : "Still trying by itself, with longer waits between attempts."
        case .lastChances:
            return "Nearly out of attempts. If the last one fails the turn stops here and you "
                + "can send it again."
        }
    }

    public var deservesNoticeElsewhere: Bool { self != .settling }
}

public struct RetryRun: Sendable, Hashable {
    public private(set) var latest: AgentRetry
    public private(set) var attempts: Int
    public let startedAt: Date

    public init(_ retry: AgentRetry, at now: Date = Date()) {
        self.latest = retry
        self.attempts = retry.attempt
        self.startedAt = now
    }

    public mutating func absorb(_ retry: AgentRetry) {
        latest = retry
        attempts = max(attempts, retry.attempt)
    }

    public var trouble: RetryTrouble { latest.trouble }
    public var patience: RetryPatience { latest.patience }

    public var recoveredSentence: String {
        let count = attempts == 1 ? "1 attempt" : "\(attempts) attempts"
        switch trouble {
        case .overloaded:
            return "Anthropic's API was overloaded. This turn got through on attempt \(attempts) of \(latest.maxAttempts)."
        case .rateLimited:
            return "Anthropic's API was rate limiting this account. This turn got through after \(count)."
        default:
            return "\(trouble.headline). This turn got through after \(count)."
        }
    }
}
