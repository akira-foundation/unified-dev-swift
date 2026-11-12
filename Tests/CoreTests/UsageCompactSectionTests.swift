import Foundation
import Testing
@testable import Core

@Suite("Compact usage section")
struct UsageCompactSectionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let options = UsageDisplayOptions(locale: Locale(identifier: "en_US"))

    private func meter(_ key: String, _ fraction: Double, resetsIn seconds: TimeInterval = 86_400) -> UsageMetric {
        UsageMetric(
            id: UsageMetricID("claudeCode/\(key)"),
            provider: .claudeCode,
            title: key,
            content: .meter(AgentQuota(
                provider: .claudeCode,
                window: .lasting(604_800, key: key),
                measure: .fraction(fraction),
                resetsAt: now.addingTimeInterval(seconds),
                observedAt: now
            ))
        )
    }

    private func value(_ key: String, _ text: String, tray: String?) -> UsageMetric {
        UsageMetric(
            id: UsageMetricID("codex/\(key)"),
            provider: .codex,
            title: key,
            content: .value(text, tray: tray, tooltip: nil)
        )
    }

    private func section(
        _ always: [UsageMetric],
        onDemand: [UsageMetric] = [],
        expanded: Bool = false
    ) -> UsageLayout.Section {
        UsageLayout.Section(provider: .claudeCode, alwaysVisible: always, onDemand: onDemand, isExpanded: expanded)
    }

    @Test("folded, only the three highest limits are drawn, the highest first")
    func highestThree() {
        let limits = [meter("a", 0.1), meter("b", 0.6), meter("c", 0.05), meter("d", 0.4), meter("e", 0.5)]
        let compact = UsageCompactSection.make(section(limits), at: now, options: options)
        #expect(compact.rows.map(\.id.rawValue) == ["claudeCode/b", "claudeCode/e", "claudeCode/d"])
        #expect(compact.folded == ["a", "c"])
        #expect(compact.foldTitle == "+2 more")
        #expect(compact.foldedNames == "a, c")
    }

    @Test("two limits used alike keep the order the owner set")
    func ties() {
        let limits = [meter("a", 0.2), meter("b", 0.2), meter("c", 0.2), meter("d", 0.2)]
        let compact = UsageCompactSection.make(section(limits), at: now, options: options)
        #expect(compact.rows.map(\.title) == ["a", "b", "c"])
        #expect(compact.folded == ["d"])
    }

    @Test("expanded, every limit is drawn and the fold offers to show less")
    func expanded() {
        let limits = [meter("a", 0.1), meter("b", 0.6), meter("c", 0.05), meter("d", 0.4)]
        let compact = UsageCompactSection.make(section(limits, expanded: true), at: now, options: options)
        #expect(compact.rows.map(\.title) == ["b", "d", "a", "c"])
        #expect(compact.isFoldable)
        #expect(compact.foldTitle == "Show less")
        #expect(compact.foldedNames == nil)
    }

    @Test("a limit the owner put on demand stays folded even with room for it")
    func onDemand() {
        let compact = UsageCompactSection.make(
            section([meter("a", 0.1)], onDemand: [meter("b", 0.9)]), at: now, options: options
        )
        #expect(compact.rows.map(\.title) == ["a"])
        #expect(compact.folded == ["b"])
    }

    @Test("with every limit on demand, the highest are still drawn rather than all folded")
    func everythingOnDemand() {
        let compact = UsageCompactSection.make(
            section([value("credits", "0 credits", tray: "0")], onDemand: [meter("month", 0.11)]),
            at: now, options: options
        )
        #expect(compact.rows.map(\.title) == ["month"])
        #expect(!compact.isFoldable)
    }

    @Test("three limits or fewer, nothing folds")
    func nothingToFold() {
        let compact = UsageCompactSection.make(section([meter("a", 0.1), meter("b", 0.2)]), at: now, options: options)
        #expect(!compact.isFoldable)
        #expect(UsageCompactSection.foldCount(section([meter("a", 0.1), meter("b", 0.2)])) == 0)
    }

    private func balances(credits: AgentAccount.Credits?, resets: Int?) -> [UsageMetric] {
        UsageCatalogue.balances(
            for: AgentAccount(
                provider: .codex,
                credits: credits,
                resetCredits: resets.map { AgentAccount.ResetCredits(available: $0, expiries: []) },
                observedAt: now
            ),
            at: now
        )
    }

    @Test("credits and resets go up into the header line and never take a limit's place")
    func summary() {
        let account = balances(credits: AgentAccount.Credits(balance: 0, isUnlimited: false), resets: 1)
        let compact = UsageCompactSection.make(
            section([meter("a", 0.1)], onDemand: account), at: now, options: options
        )
        #expect(compact.summary == "0 credits, 1 reset")
        #expect(compact.rows.map(\.title) == ["a"])
        #expect(!compact.isFoldable)
        #expect(UsageCompactSection.summary(of: balances(credits: nil, resets: 3)) == "3 resets")
        let unlimited = balances(credits: AgentAccount.Credits(balance: 0, isUnlimited: true), resets: nil)
        #expect(UsageCompactSection.summary(of: unlimited) == "Unlimited credits")
        #expect(UsageCompactSection.summary(of: [meter("a", 0.1)]) == nil)
    }

    @Test("a row says the share used and the time left until it resets")
    func row() {
        let compact = UsageCompactSection.make(
            section([meter("a", 0.81, resetsIn: 26 * 60)]), at: now, options: options
        )
        let row = compact.rows.first
        #expect(row?.value == "81%")
        #expect(row?.reset == "26m")
        #expect(row?.resetHelp == "Resets in 26m")
        #expect(row?.alert == nil)
        #expect(row?.showsFlame == false)
    }

    @Test("a limit running out before it resets carries the flame and the time until it runs out")
    func runningOut() {
        let compact = UsageCompactSection.make(
            section([meter("a", 0.5, resetsIn: 6 * 86_400)]), at: now, options: options
        )
        let row = compact.rows.first
        #expect(row?.showsFlame == true)
        #expect(row?.alert == "1d 0h")
        #expect(row?.reset == "6d 0h")
        #expect(row?.reading.tone == .critical)
    }
}
