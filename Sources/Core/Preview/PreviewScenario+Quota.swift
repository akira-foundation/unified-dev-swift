import Foundation

extension PreviewScenario {
    public static let holdsQuotasKey = "preview.holdsSeededQuotas"

    public struct Quota: Sendable, Equatable, Codable {
        public var provider: AgentKind
        public var window: String
        public var label: String?
        public var hours: Double?
        public var used: Double?
        public var resetsInMinutes: Double?

        public init(
            provider: AgentKind,
            window: String,
            label: String? = nil,
            hours: Double? = nil,
            used: Double? = nil,
            resetsInMinutes: Double? = nil
        ) {
            self.provider = provider
            self.window = window
            self.label = label
            self.hours = hours
            self.used = used
            self.resetsInMinutes = resetsInMinutes
        }

        public var id: String { "\(provider.rawValue)/\(window)" }

        public func quota(at now: Date) -> AgentQuota {
            let named = QuotaWindow.named(window)
            let duration = hours.map { $0 * 3600 } ?? named.duration
            let fallback = hours.map { QuotaWindow.label(forSeconds: $0 * 3600) } ?? named.label
            return AgentQuota(
                provider: provider,
                window: QuotaWindow(key: window, label: label ?? fallback, duration: duration),
                measure: used.map { .fraction($0) } ?? .unknown,
                resetsAt: resetsInMinutes.map { now.addingTimeInterval($0 * 60) },
                observedAt: now
            )
        }
    }

    var quotaProblems: [String] {
        var problems: [String] = []
        var seen = Set<String>()
        for quota in quotas {
            let name = quota.id
            if !quota.provider.publishesUsage {
                problems.append("quota \(name) names an agent that reports no usage")
            }
            if quota.window.trimmingCharacters(in: .whitespaces).isEmpty {
                problems.append("a quota for \(quota.provider.rawValue) names no window")
            }
            if let used = quota.used, used < 0 {
                problems.append("quota \(name) uses a negative amount")
            }
            if let used = quota.used, used > 1 {
                problems.append("quota \(name) uses more than the whole limit; used is a fraction, 1 is a limit reached")
            }
            if let hours = quota.hours, hours <= 0 {
                problems.append("quota \(name) lasts no time at all")
            }
            if let minutes = quota.resetsInMinutes, minutes <= 0 {
                problems.append("quota \(name) resets in the past")
            }
            if !seen.insert(name).inserted {
                problems.append("quota \(name) is named twice")
            }
        }
        return problems
    }
}
