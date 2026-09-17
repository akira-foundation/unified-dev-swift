import Foundation

public struct MenuBarUsageStrip: Sendable, Hashable {
    public struct Group: Sendable, Hashable, Identifiable {
        public var provider: AgentKind
        public var values: [String]
        public var id: AgentKind { provider }
    }

    public static let maximumBars = 4

    public var groups: [Group]
    public var bars: [Double]
    public var spoken: String

    public var isEmpty: Bool { groups.isEmpty }

    public init(groups: [Group] = [], bars: [Double] = [], spoken: String = "") {
        self.groups = groups
        self.bars = bars
        self.spoken = spoken
    }

    public static func make(
        layout: UsageLayout,
        metrics: [AgentKind: [UsageMetric]],
        at now: Date = Date(),
        options: UsageDisplayOptions = UsageDisplayOptions()
    ) -> MenuBarUsageStrip {
        var groups: [Group] = []
        var bars: [Double] = []
        var spoken: [String] = []

        for (provider, starred) in layout.pinnedMetrics(in: metrics) {
            var values: [String] = []
            var phrases: [String] = []
            for metric in starred {
                switch metric.content {
                case .meter(let quota):
                    let reading = UsageMeterReading.of(quota, isSession: metric.isSession, at: now, options: options)
                    guard let value = reading.menuBarValue else { continue }
                    values.append(value)
                    phrases.append("\(metric.title) \(reading.headline)")
                    if bars.count < maximumBars { bars.append(reading.fill) }
                case .value(let text, let tray, _):
                    guard let tray else { continue }
                    values.append(tray)
                    phrases.append("\(metric.title) \(text)")
                }
            }
            guard !values.isEmpty else { continue }
            groups.append(Group(provider: provider, values: values))
            spoken.append("\(provider.label) \(phrases.joined(separator: ", "))")
        }
        return MenuBarUsageStrip(groups: groups, bars: bars, spoken: spoken.joined(separator: "; "))
    }
}
