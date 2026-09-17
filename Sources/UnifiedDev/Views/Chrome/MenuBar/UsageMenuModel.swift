import AppKit
import SwiftUI
import Core

@MainActor
@Observable
final class UsageMenuModel {
    static let shared = UsageMenuModel()

    private(set) var layout: UsageLayout

    var showsUsage: Bool {
        didSet { defaults.set(showsUsage, forKey: UsagePreferenceKey.showsUsage) }
    }
    var showsCup: Bool {
        didSet { defaults.set(showsCup, forKey: UsagePreferenceKey.showsCup) }
    }
    var showsWaitingCount: Bool {
        didSet { defaults.set(showsWaitingCount, forKey: UsagePreferenceKey.showsWaitingCount) }
    }
    var showsUnreadCount: Bool {
        didSet { defaults.set(showsUnreadCount, forKey: UsagePreferenceKey.showsUnreadCount) }
    }
    var meterStyle: UsageMeterStyle {
        didSet { defaults.set(meterStyle.rawValue, forKey: UsagePreferenceKey.meterStyle) }
    }
    var iconStyle: MenuBarIconStyle {
        didSet { defaults.set(iconStyle.rawValue, forKey: UsagePreferenceKey.iconStyle) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var refresh: () -> Void = {}

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        layout = UsageLayout.load(from: defaults)
        showsUsage = defaults.object(forKey: UsagePreferenceKey.showsUsage) as? Bool ?? true
        showsCup = defaults.object(forKey: UsagePreferenceKey.showsCup) as? Bool ?? true
        showsWaitingCount = defaults.object(forKey: UsagePreferenceKey.showsWaitingCount) as? Bool ?? true
        showsUnreadCount = defaults.object(forKey: UsagePreferenceKey.showsUnreadCount) as? Bool ?? true
        meterStyle = defaults.string(forKey: UsagePreferenceKey.meterStyle)
            .flatMap(UsageMeterStyle.init(rawValue:)) ?? .left
        iconStyle = defaults.string(forKey: UsagePreferenceKey.iconStyle)
            .flatMap(MenuBarIconStyle.init(rawValue:)) ?? .text
    }

    var options: UsageDisplayOptions { UsageDisplayOptions(meterStyle: meterStyle) }

    func update(_ change: (inout UsageLayout) -> Void) {
        var copy = layout
        change(&copy)
        guard copy != layout else { return }
        layout = copy
        layout.save(to: defaults)
    }

    func adopt(_ metrics: [AgentKind: [UsageMetric]]) {
        update { $0.adopt(metrics) }
    }

    func move(_ provider: AgentKind, toward target: AgentKind) {
        update { $0.moveProvider(provider, toward: target) }
    }

    @discardableResult
    func togglePin(_ metric: UsageMetric) -> UsageLayout.PinOutcome {
        var outcome = UsageLayout.PinOutcome.unpinned
        update { outcome = $0.togglePin(metric) }
        return outcome
    }

    func metrics(quotas: [AgentQuota], accounts: [AgentKind: AgentAccount], at now: Date = Date()) -> [AgentKind: [UsageMetric]] {
        let metrics = UsageCatalogue.metrics(quotas: quotas, accounts: accounts, at: now)
        adopt(metrics)
        return metrics
    }
}
