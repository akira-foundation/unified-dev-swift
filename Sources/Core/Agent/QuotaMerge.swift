import Foundation

public enum QuotaMerge {
    public static func merged(_ known: [AgentQuota], with reported: [AgentQuota]) -> [AgentQuota] {
        var byID = Dictionary(known.map { ($0.id, $0) }, uniquingKeysWith: { _, later in later })
        for row in reported {
            byID[row.id] = resolve(row, against: byID[row.id])
        }
        return byID.values.sorted { $0.id < $1.id }
    }

    public static func resolved(_ reported: [AgentQuota], against known: [AgentQuota]) -> [AgentQuota] {
        let byID = Dictionary(known.map { ($0.id, $0) }, uniquingKeysWith: { _, later in later })
        return reported.map { resolve($0, against: byID[$0.id]) }
    }

    public static func resolve(_ reported: AgentQuota, against known: AgentQuota?) -> AgentQuota {
        guard let known else { return reported }
        guard reported.observedAt >= known.observedAt else { return known }

        var merged = reported
        merged.resetsAt = reported.resetsAt ?? known.resetsAt

        let turnedOver: Bool
        if let old = known.resetsAt, let new = merged.resetsAt {
            turnedOver = old != new
        } else {
            turnedOver = false
        }
        guard !turnedOver else { return merged }

        if !reported.measure.isKnown { merged.measure = known.measure }
        if reported.window.duration == nil, known.window.duration != nil {
            merged.window = known.window
        }
        return merged
    }
}

public enum QuotaFreshness: Sendable, Hashable {
    case current
    case stale(TimeInterval)

    public static let threshold = max(300, QuotaPollSchedule.interval * 3)

    public static func of(_ observedAt: Date, at now: Date = Date()) -> QuotaFreshness {
        let age = now.timeIntervalSince(observedAt)
        return age > threshold ? .stale(age) : .current
    }

    public static func of(_ board: QuotaBoard, at now: Date = Date()) -> QuotaFreshness {
        guard let oldest = board.all.map(\.observedAt).min() else { return .current }
        return of(oldest, at: now)
    }

    public var phrase: String? {
        guard case .stale(let age) = self else { return nil }
        if age < 3600 { return "\(Int((age / 60).rounded(.down))) min ago" }
        if age < 86_400 {
            let hours = Int((age / 3600).rounded(.down))
            return hours == 1 ? "an hour ago" : "\(hours) hours ago"
        }
        let days = Int((age / 86_400).rounded(.down))
        return days == 1 ? "yesterday" : "\(days) days ago"
    }
}
