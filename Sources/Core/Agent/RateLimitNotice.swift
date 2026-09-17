import Foundation

public enum RateLimitNotice {
    public static func sentence(forRateLimitEvent data: Data, at now: Date = Date()) -> String? {
        let quotas = AgentQuotaAdapters.quotas(fromRateLimitEvent: data, at: now)
        guard let worst = quotas.compactMap({ quota -> (String, Double)? in
            guard let fraction = quota.measure.fraction else { return nil }
            return (quota.window.label, fraction)
        }).max(by: { $0.1 < $1.1 }) else { return nil }

        let percent = Int((worst.1 * 100).rounded())
        return "\(percent)% of the \(worst.0.lowercased()) allowance used"
    }
}
