import Foundation

public struct AgentAccount: Sendable, Hashable {
    public var provider: AgentKind
    public var plan: String?
    public var credits: Credits?
    public var resetCredits: ResetCredits?
    public var observedAt: Date

    public struct Credits: Sendable, Hashable {
        public var balance: Double
        public var isUnlimited: Bool

        public init(balance: Double, isUnlimited: Bool = false) {
            self.balance = balance
            self.isUnlimited = isUnlimited
        }
    }

    public struct ResetCredits: Sendable, Hashable {
        public var available: Int
        public var expiries: [Date]

        public init(available: Int, expiries: [Date] = []) {
            self.available = available
            self.expiries = expiries
        }
    }

    public init(
        provider: AgentKind,
        plan: String? = nil,
        credits: Credits? = nil,
        resetCredits: ResetCredits? = nil,
        observedAt: Date
    ) {
        self.provider = provider
        self.plan = plan
        self.credits = credits
        self.resetCredits = resetCredits
        self.observedAt = observedAt
    }
}

public enum AgentAccountReader {
    public static func account(from data: Data, at now: Date = Date()) -> AgentAccount? {
        guard let line = JSONValue.parse(data) else { return nil }
        return claudeCode(line, at: now) ?? codex(line, at: now)
    }

    static func claudeCode(_ line: JSONValue, at now: Date) -> AgentAccount? {
        let payload = line["response"]?["response"] ?? line
        guard payload["session"] != nil || payload["rate_limits_available"] != nil else { return nil }
        return AgentAccount(
            provider: .claudeCode,
            plan: payload["subscription_type"]?.stringValue.flatMap(claudePlan),
            observedAt: now
        )
    }

    static func codex(_ line: JSONValue, at now: Date) -> AgentAccount? {
        let codex = line["codex"] ?? line
        let body = codex["result"] ?? codex["params"] ?? codex
        guard let limits = body["rateLimits"] else { return nil }

        var credits: AgentAccount.Credits?
        if let raw = limits["credits"] {
            let unlimited = raw["unlimited"]?.boolValue ?? false
            let balance = raw["balance"]?.doubleValue
                ?? raw["balance"]?.stringValue.flatMap(Double.init)
                ?? (raw["hasCredits"]?.boolValue == false ? 0 : nil)
            if let balance { credits = .init(balance: max(0, balance.rounded(.down)), isUnlimited: unlimited) }
        }

        var resets: AgentAccount.ResetCredits?
        if let raw = body["rateLimitResetCredits"], let count = raw["availableCount"]?.intValue, count >= 0 {
            let expiries = (raw["credits"]?.arrayValue ?? [])
                .filter { ($0["status"]?.stringValue ?? "available") == "available" }
                .compactMap { $0["expiresAt"]?.doubleValue.map(Date.init(timeIntervalSince1970:)) }
                .sorted()
            resets = .init(available: count, expiries: expiries)
        }

        return AgentAccount(
            provider: .codex,
            plan: limits["planType"]?.stringValue.flatMap(codexPlan),
            credits: credits,
            resetCredits: resets,
            observedAt: now
        )
    }

    public static func claudePlan(_ raw: String) -> String? {
        let words = raw.split(whereSeparator: { $0 == "_" || $0 == " " })
        guard !words.isEmpty else { return nil }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
    }

    public static func codexPlan(_ raw: String) -> String? {
        switch raw.lowercased() {
        case "": return nil
        case "prolite": return "Pro 5x"
        case "pro": return "Pro 20x"
        case "self_serve_business_prolite": return "Business Premium"
        default:
            return raw.split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}
