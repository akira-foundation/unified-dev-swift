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
