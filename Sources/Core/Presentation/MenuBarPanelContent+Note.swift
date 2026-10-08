import Foundation

extension MenuBarPanelContent {
    public static let settledReading: TimeInterval = 180

    public static func silentLine(for provider: AgentKind) -> String {
        "\(provider.label) did not answer."
    }

    public static func lastReportedLine(for provider: AgentKind, since date: Date, from now: Date) -> String {
        "\(provider.label) last reported its limits \(age(since: date, from: now)) ago."
    }

    public static func sinceLine(since date: Date, from now: Date) -> String {
        "Last reported \(age(since: date, from: now)) ago."
    }

    public static func readLine(age: TimeInterval) -> String {
        "Read \(UsageFormat.compactDuration(age)) ago"
    }

    static func age(since date: Date, from now: Date) -> String {
        UsageFormat.compactDuration(max(0, now.timeIntervalSince(date)))
    }

    static func reason(for provider: AgentKind, in input: Input) -> String {
        let reportedAt = input.lastReported[provider]
        guard !input.unanswered.contains(provider) else {
            guard let reportedAt else { return silentLine(for: provider) }
            return "\(silentLine(for: provider)) \(sinceLine(since: reportedAt, from: input.now))"
        }
        guard let reportedAt else { return unavailableLine(for: provider) }
        return lastReportedLine(for: provider, since: reportedAt, from: input.now)
    }

    static func ageNote(drawing section: UsageLayout.Section, at now: Date) -> String? {
        guard let readAt = section.visible.compactMap({ $0.quota?.observedAt }).min() else { return nil }
        let age = now.timeIntervalSince(readAt)
        guard age > settledReading else { return nil }
        return readLine(age: age)
    }
}
