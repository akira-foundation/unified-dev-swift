import Testing
import Foundation
@testable import Core

private let now = Date(timeIntervalSince1970: 1_787_500_000)

private let english = Locale(identifier: "en_GB")
private let american = Locale(identifier: "en_US")

private let week: TimeInterval = 604_800

private func quota(
    _ provider: AgentKind = .claudeCode,
    _ window: QuotaWindow = .named("seven_day"),
    used: Double?,
    resets: TimeInterval?
) -> AgentQuota {
    AgentQuota(
        provider: provider,
        window: window,
        measure: used.map { .fraction($0) } ?? .unknown,
        resetsAt: resets.map { now.addingTimeInterval($0) },
        observedAt: now
    )
}

@Suite("Quota severity ramp")
struct QuotaSeverityRampTests {
    @Test func stepsAtEightyAndNinety() {
        #expect(QuotaSeverity.warningAt == 0.8)
        #expect(QuotaSeverity.criticalAt == 0.9)
        #expect(QuotaSeverity.of(0.79) == .calm)
        #expect(QuotaSeverity.of(0.85) == .warning)
        #expect(QuotaSeverity.of(0.95) == .critical)
        #expect(QuotaSeverity.of(1.0) == .spent)
        #expect(QuotaSeverity.of(1.03) == .spent)
    }

    @Test func takesTheBoundaryItselfAsTheNewStep() {
        #expect(QuotaSeverity.of(0.8) == .warning)
        #expect(QuotaSeverity.of(0.9) == .critical)
        #expect(QuotaPhrase.figure(for: quota(used: 0.8, resets: 3600)) == "80%")
        #expect(QuotaPhrase.figure(for: quota(used: 0.9, resets: 3600)) == "90%")
    }
}

@Suite("Quota pace")
struct QuotaPaceTests {
    @Test func measuresHowFarAheadOfItsOwnClockAWindowIs() throws {
        let pace = try #require(QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 0.6, resets: week / 2), at: now
        ))
        #expect(abs(pace.elapsed - 0.5) < 0.0001)
        #expect(abs(pace.overspend - 0.1) < 0.0001)
    }

    @Test func isNotAheadWhenTheAllowanceIsOutlastingTheClock() throws {
        let pace = try #require(QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 0.2, resets: week / 2), at: now
        ))
        #expect(pace.overspend == 0)
        #expect(pace.runsOutIn == nil)
    }

    @Test func forecastsRunningOutBeforeTheWindowLifts() throws {
        let elapsed = week * 0.4643
        let pace = try #require(QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 0.71, resets: week - elapsed), at: now
        ))
        let seconds = try #require(pace.runsOutIn)
        #expect(seconds > 100_000 && seconds < 130_000)
        #expect(QuotaCountdown.phrase(after: seconds) == "in 1d 7h")
        #expect(QuotaCountdown.rough(after: seconds) == "in about a day")
    }

    @Test func saysNothingWhenTheAllowanceWillSeeTheWindowOut() {
        let pace = QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 0.5, resets: week * 0.2), at: now
        )
        #expect(pace?.runsOutIn == nil)
    }

    @Test func willNotForecastAShortfallItOnlyJustReaches() throws {
        let pace = try #require(QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 0.6, resets: 260_000), at: now
        ))
        #expect(pace.overspend > 0)
        #expect(pace.runsOutIn == nil)
    }

    @Test func willNotForecastFromTheFirstMomentsOfAWindow() {
        let pace = QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 0.3, resets: week * 0.95), at: now
        )
        #expect(pace?.runsOutIn == nil)
    }

    @Test func forecastsNothingForASpentWindowOrAnUntouchedOne() {
        let spent = QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 1, resets: week / 2), at: now
        )
        let untouched = QuotaPace.of(
            quota(.claudeCode, .named("seven_day"), used: 0, resets: week / 2), at: now
        )
        #expect(spent?.runsOutIn == nil)
        #expect(untouched?.runsOutIn == nil)
    }

    @Test func declinesAWindowThatCannotBePaced() {
        #expect(QuotaPace.of(quota(used: nil, resets: 3600), at: now) == nil)
        #expect(QuotaPace.of(quota(used: 0.5, resets: nil), at: now) == nil)
        #expect(QuotaPace.of(
            quota(.claudeCode, QuotaWindow(key: "extra_usage", label: "Extra usage"),
                  used: 0.5, resets: 3600),
            at: now
        ) == nil)
    }
}

@Suite("Quota phrasing")
struct QuotaPhraseTests {
    @Test func saysWhenEveryWindowLiftsInTheSameWords() {
        let weekly = quota(.claudeCode, .named("seven_day"), used: 0.6, resets: 260_000)
        let session = quota(.claudeCode, .named("five_hour"), used: 0.04, resets: 11_580)
        #expect(QuotaPhrase.footnote(for: weekly, at: now, locale: english) == "Lifts in 3d")
        #expect(QuotaPhrase.footnote(for: session, at: now, locale: english) == "Lifts in 3h 13m")
    }

    @Test func roundsAFigureDown() {
        #expect(QuotaPhrase.figure(for: quota(used: 0.999, resets: 3600)) == "99%")
        #expect(QuotaPhrase.figure(for: quota(used: 0, resets: 3600)) == "0%")
        #expect(QuotaPhrase.figure(for: quota(used: 1.03, resets: 3600)) == "100%")
    }

    @Test func willNotPrintAZeroForAWindowNobodyMeasured() {
        #expect(QuotaPhrase.figure(for: quota(used: nil, resets: 3600)) == "not reported")
    }

    @Test func addsTheForecastOnlyWhereItIsTrue() {
        let elapsed = week * 0.4643
        let pressed = quota(.claudeCode, .named("seven_day"), used: 0.71, resets: week - elapsed)
        let calm = quota(.claudeCode, .named("seven_day"), used: 0.2, resets: week - elapsed)
        #expect(QuotaPhrase.footnote(for: pressed, at: now, forecasting: true, locale: english)
            == "Lifts in 3d. At this rate it runs out in about a day")
        #expect(QuotaPhrase.footnote(for: calm, at: now, forecasting: true, locale: english)
            == "Lifts in 3d")
        #expect(QuotaPhrase.footnote(for: pressed, at: now, locale: english) == "Lifts in 3d")
    }

    @Test func saysMoneyAsMoney() {
        let extra = AgentQuota(
            provider: .claudeCode,
            window: QuotaWindow(key: "extra_usage", label: "Extra usage"),
            measure: .counted(used: 17.2, limit: 50, unit: "USD"),
            resetsAt: nil,
            observedAt: now
        )
        #expect(QuotaPhrase.footnote(for: extra, at: now, locale: american) == "$17.20 of $50.00")
        #expect(QuotaPhrase.footnote(for: extra, at: now, locale: english) == "US$17.20 of US$50.00")
    }

    @Test func saysAnAmountWithNoCeilingAsAnAmount() {
        let extra = AgentQuota(
            provider: .claudeCode,
            window: QuotaWindow(key: "extra_usage", label: "Extra usage"),
            measure: .counted(used: 4, limit: nil, unit: "USD"),
            resetsAt: nil,
            observedAt: now
        )
        #expect(QuotaPhrase.footnote(for: extra, at: now, locale: american) == "$4.00 so far")
    }
}

@Suite("Quota lines")
struct QuotaLineTests {
    private func board(_ quotas: [AgentQuota]) -> QuotaBoard { QuotaBoard.make(from: quotas, at: now) }

    @Test func drawsEachProviderInTurnShortestWindowFirst() {
        let lines = board([
            quota(.codex, .lasting(week, key: "primary"), used: 0, resets: week / 2),
            quota(.claudeCode, .named("seven_day"), used: 0.6, resets: week / 2),
            quota(.claudeCode, .named("five_hour"), used: 0.04, resets: 3600),
        ]).lines(at: now, locale: english)

        #expect(lines.map(\.title) == [
            "Claude Code · 5 hours", "Claude Code · Week", "Codex · Week",
        ])
    }

    @Test func putsAWindowOfUnstatedLengthLastWithinItsProvider() {
        let lines = board([
            AgentQuota(
                provider: .claudeCode,
                window: QuotaWindow(key: "extra_usage", label: "Extra usage"),
                measure: .counted(used: 17.2, limit: 50, unit: "USD"),
                resetsAt: nil,
                observedAt: now
            ),
            quota(.claudeCode, .named("seven_day"), used: 0.6, resets: week / 2),
            quota(.claudeCode, .named("five_hour"), used: 0.04, resets: 3600),
        ]).lines(at: now, locale: english)

        #expect(lines.map(\.windowKey) == ["five_hour", "seven_day", "extra_usage"])
    }

    @Test func keepsTwoWeekliesInAStableOrder() {
        let scoped = AgentQuota(
            provider: .claudeCode,
            window: QuotaWindow(key: "seven_day_model_fable", label: "Week (Fable)", duration: week),
            measure: .fraction(0.71),
            resetsAt: now.addingTimeInterval(week / 2),
            observedAt: now
        )
        let lines = board([
            scoped,
            quota(.claudeCode, .named("seven_day"), used: 0.6, resets: week / 2),
        ]).lines(at: now, locale: english)

        #expect(lines.map(\.title) == ["Claude Code · Week", "Claude Code · Week (Fable)"])
    }

    @Test func givesAnUnmeasuredWindowNoPlaceOnTheRamp() throws {
        let lines = board([
            quota(.claudeCode, .named("five_hour"), used: nil, resets: 3600),
            quota(.claudeCode, .named("seven_day"), used: 0, resets: week / 2),
        ]).lines(at: now, locale: english)

        #expect(lines[0].severity == nil)
        #expect(lines[0].fill == nil)
        #expect(lines[0].figure == "not reported")
        #expect(lines[1].severity == .calm)
        #expect(lines[1].fill == 0)
        #expect(lines[1].figure == "0%")
    }

    @Test func drawsNothingAtAllForAnAbsentProvider() {
        let lines = board([
            quota(.claudeCode, .named("five_hour"), used: 0.5, resets: 3600),
        ]).lines(at: now, locale: english)

        #expect(lines.count == 1)
        #expect(lines.allSatisfy { $0.provider == .claudeCode })
    }

    @Test func namesTheNearestWallSeparatelyFromTheOrderItDrawsIn() {
        let made = board([
            quota(.claudeCode, .named("five_hour"), used: 0.04, resets: 3600),
            quota(.claudeCode, .named("seven_day"), used: 0.93, resets: week / 2),
        ])
        #expect(made.lines(at: now, locale: english).first?.windowKey == "five_hour")
        #expect(made.headline?.window.key == "seven_day")
        #expect(made.severity == .critical)
    }

    @Test func letsOnlyTheWorstRowSayWhatItsRateMeans() {
        let elapsed = week * 0.45
        let made = board([
            AgentQuota(
                provider: .claudeCode,
                window: QuotaWindow(key: "seven_day_model_fable", label: "Week (Fable)", duration: week),
                measure: .fraction(0.71),
                resetsAt: now.addingTimeInterval(week - elapsed),
                observedAt: now
            ),
            quota(.claudeCode, .named("seven_day"), used: 0.62, resets: week - elapsed),
        ])
        let lines = made.lines(at: now, locale: english)

        #expect(made.forecastable(at: now)?.window.key == "seven_day_model_fable")
        #expect(lines.filter { $0.footnote.contains("this rate") }.count == 1)
        #expect(lines.first { $0.windowKey == "seven_day_model_fable" }?
            .footnote.contains("At this rate") == true)
    }

    @Test func tellsTheSameTwoPercentagesApartByTheirClocks() {
        let made = board([
            quota(.claudeCode, .named("five_hour"), used: 0.95, resets: 1200),
            quota(.claudeCode, .named("seven_day"), used: 0.95, resets: week * 0.85),
        ])
        #expect(made.headline?.window.key == "seven_day")
        let lines = made.lines(at: now, locale: english)
        #expect(lines.map(\.severity) == [.critical, .critical])
    }
}
