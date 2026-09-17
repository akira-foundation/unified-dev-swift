import Foundation

public struct QuotaPace: Sendable, Hashable {
    public var used: Double
    public var elapsed: Double
    public var remaining: TimeInterval

    public var overspend: Double { max(0, used - elapsed) }

    public var runsOutIn: TimeInterval?

    public static let minimumElapsed = 0.1

    public static let clearance = 0.75

    public static func of(_ quota: AgentQuota, at now: Date) -> QuotaPace? {
        guard let used = quota.fraction,
              let resetsAt = quota.resetsAt,
              let duration = quota.window.duration, duration > 0
        else { return nil }

        let remaining = resetsAt.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        let elapsed = min(max(1 - remaining / duration, 0), 1)

        return QuotaPace(
            used: used,
            elapsed: elapsed,
            remaining: remaining,
            runsOutIn: runsOut(used: used, elapsed: elapsed, duration: duration, remaining: remaining)
        )
    }

    static func runsOut(
        used: Double,
        elapsed: Double,
        duration: TimeInterval,
        remaining: TimeInterval
    ) -> TimeInterval? {
        guard used > 0, used < 1, elapsed >= minimumElapsed else { return nil }
        let secondsSoFar = duration * elapsed
        let seconds = (1 - used) * secondsSoFar / used
        guard seconds < remaining * clearance else { return nil }
        return seconds
    }
}

public enum QuotaPhrase {
    public static let heading = "LIMITS"

    public static let notReported = "not reported"

    public static func title(for quota: AgentQuota) -> String {
        "\(quota.provider.label) · \(quota.window.label)"
    }

    public static func figure(for quota: AgentQuota) -> String {
        guard let fraction = quota.fraction else { return notReported }
        return "\(Int((min(max(fraction, 0), 1) * 100).rounded(.down)))%"
    }

    public static func footnote(
        for quota: AgentQuota,
        at now: Date,
        forecasting: Bool = false,
        locale: Locale = .current
    ) -> String {
        var parts: [String] = []
        if case .counted(let used, let limit, let unit) = quota.measure {
            parts.append(spend(used: used, limit: limit, code: unit, locale: locale))
        }
        if let resetsAt = quota.resetsAt {
            parts.append("Lifts \(QuotaCountdown.phrase(until: resetsAt, from: now))")
        }
        if forecasting, let seconds = QuotaPace.of(quota, at: now)?.runsOutIn {
            parts.append("at this rate it runs out \(QuotaCountdown.rough(after: seconds))")
        }
        return parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: ". ")
    }

    static func spend(used: Double, limit: Double?, code: String, locale: Locale) -> String {
        guard let limit else { return "\(money(used, code: code, locale: locale)) so far" }
        return "\(money(used, code: code, locale: locale)) of "
            + "\(money(limit, code: code, locale: locale))"
    }

    static func money(_ amount: Double, code: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code.uppercased()
        return formatter.string(from: NSNumber(value: amount))
            ?? String(format: "%.2f %@", amount, code.uppercased())
    }
}

public struct QuotaLine: Sendable, Hashable, Identifiable {
    public var provider: AgentKind
    public var windowKey: String
    public var id: String { "\(provider.rawValue)/\(windowKey)" }

    public var title: String
    public var figure: String
    public var fill: Double?
    public var severity: QuotaSeverity?
    public var footnote: String

    public var spoken: String {
        var parts = [title, figure]
        if let word = severity?.word { parts.append(word) }
        if !footnote.isEmpty { parts.append(footnote) }
        return parts.joined(separator: ", ")
    }

    public init(
        provider: AgentKind,
        windowKey: String,
        title: String,
        figure: String,
        fill: Double?,
        severity: QuotaSeverity?,
        footnote: String
    ) {
        self.provider = provider
        self.windowKey = windowKey
        self.title = title
        self.figure = figure
        self.fill = fill
        self.severity = severity
        self.footnote = footnote
    }

    public static func of(
        _ quota: AgentQuota,
        at now: Date,
        forecasting: Bool = false,
        locale: Locale = .current
    ) -> QuotaLine {
        let fraction = quota.fraction
        return QuotaLine(
            provider: quota.provider,
            windowKey: quota.window.key,
            title: QuotaPhrase.title(for: quota),
            figure: QuotaPhrase.figure(for: quota),
            fill: fraction.map { min(max($0, 0), 1) },
            severity: fraction.map(QuotaSeverity.of),
            footnote: QuotaPhrase.footnote(
                for: quota, at: now, forecasting: forecasting, locale: locale
            )
        )
    }
}
