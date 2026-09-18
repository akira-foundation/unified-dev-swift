import Foundation

extension MenuBarPanelContent {
    static let lowercasedTitles: Set<String> = ["Session", "Weekly"]

    static func sentence(
        running: Int,
        workspaces: Int,
        waiting: Int,
        notices: [LimitNotice],
        hold: KeepAwake.Hold,
        needsSetup: Bool,
        now: Date
    ) -> String {
        var parts: [String] = []
        if running > 0 { parts.append(runningPhrase(agents: running, workspaces: workspaces)) }
        if waiting > 0 { parts.append("\(Counted.of(waiting, "agent")) waiting on you.") }
        if parts.isEmpty { parts.append(noAgentsLine + ".") }
        parts += notices.map { limitPhrase($0, now: now) }
        if let awake = awakePhrase(hold, now: now) { parts.append(awake) }
        if needsSetup { parts.append(setupSentence) }
        return parts.joined(separator: " ")
    }

    static func runningPhrase(agents: Int, workspaces: Int) -> String {
        let count = Counted.of(agents, "agent")
        guard workspaces > 0 else { return "\(count) running." }
        return "\(count) running in \(Counted.of(workspaces, "workspace"))."
    }

    static func limitPhrase(_ notice: LimitNotice, now: Date) -> String {
        let title = lowercasedTitles.contains(notice.title) ? notice.title.lowercased() : notice.title
        let limit = "\(notice.provider.label) \(title) limit reached"
        guard let resetsAt = notice.resetsAt else { return limit + "." }
        return "\(limit), resets \(QuotaCountdown.phrase(until: resetsAt, from: now))."
    }

    static func awakePhrase(_ hold: KeepAwake.Hold, now: Date) -> String? {
        switch hold {
        case .none: nil
        case .whileAgentsRun: "The Mac stays awake until they finish."
        case .until(let end): "Keep Awake is on for \(UsageFormat.compactDuration(end.timeIntervalSince(now))) more."
        case .indefinitely: "Keep Awake is on until you turn it off."
        }
    }
}
