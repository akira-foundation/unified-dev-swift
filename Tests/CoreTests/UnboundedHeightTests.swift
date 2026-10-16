import Foundation
import Testing
@testable import Core

@Suite("UnboundedHeight")
struct UnboundedHeightTests {
    private static let home = WindowInk(onArrival: 0.0225, afterRedraw: 0.0225)

    @Test("every subject the issue named is listed once, with a file, a line and a way in")
    func everySubjectIsListed() {
        let subjects = UnboundedHeightSubject.all
        #expect(subjects.count == 12)
        #expect(Set(subjects.map(\.key)).count == 12)
        #expect(Set(subjects.map { "\($0.file):\($0.line)" }).count == 12)
        for subject in subjects {
            #expect(subject.file.hasPrefix("Sources/UnifiedDev/Views/"))
            #expect(subject.file.hasSuffix(".swift"))
            #expect(subject.line > 0)
            #expect(subject.path.count > 40)
            #expect(subject.path.hasSuffix("."))
        }
    }

    @Test("the readings taken for the archive card in #241 are what the rule was built on")
    func theArchiveReadingsDecide() {
        let archived = WindowInk(onArrival: 0.0087, afterRedraw: 0.0087)
        let live = WindowInk(onArrival: 0.0344, afterRedraw: 0.0344)
        let fixed = WindowInk(onArrival: 0.0332, afterRedraw: 0.0330)
        #expect(archived.verdict(against: Self.home) == .stoppedDrawing)
        #expect(live.verdict(against: Self.home) == .drew)
        #expect(fixed.verdict(against: Self.home) == .drew)
        #expect(Self.home.verdict(against: Self.home) == .drew)
    }

    @Test("three quarters of the baseline is where the rule turns, and the figure is the rule")
    func theShareIsWhereTheRuleTurns() {
        let baseline = WindowInk(onArrival: 0.02, afterRedraw: 0.02)
        #expect(WindowInk(onArrival: 0.015, afterRedraw: 0.015).verdict(against: baseline) == .drew)
        #expect(
            WindowInk(onArrival: 0.0149, afterRedraw: 0.015).verdict(against: baseline)
                == .stoppedDrawing
        )
        #expect(
            WindowInk(onArrival: 0.015, afterRedraw: 0.0149).verdict(against: baseline)
                == .stoppedDrawing
        )
        #expect(WindowInk.share == 0.75)
    }

    @Test("a baseline that fell on its second reading is judged by the lower of the two")
    func theBaselineIsJudgedByItsWorstReading() {
        let faded = WindowInk(onArrival: 0.04, afterRedraw: 0.01)
        let steady = WindowInk(onArrival: 0.02, afterRedraw: 0.02)
        #expect(steady.verdict(against: faded) == .drew)
    }

    @Test("a screen that could not be read is said to be unread rather than drawn or blank")
    func anUnreadScreenIsNotAVerdict() {
        #expect(WindowInk.unreadable.verdict(against: Self.home) == .unreadable)
        #expect(WindowInk(onArrival: 0.02, afterRedraw: -1).verdict(against: Self.home) == .unreadable)
        let blankBaseline = WindowInk(onArrival: 0, afterRedraw: 0)
        #expect(Self.home.verdict(against: blankBaseline) == .unreadable)
        #expect(Self.home.verdict(against: .unreadable) == .unreadable)
    }

    @Test("a height is bounded only while it is finite and inside the ceiling")
    func aHeightIsBoundedOrItIsNot() {
        #expect(HeightRequest(width: 420, height: 64).isBounded)
        #expect(HeightRequest(width: 420, height: 0).isBounded)
        #expect(!HeightRequest(width: 420, height: .infinity).isBounded)
        #expect(!HeightRequest(width: 420, height: .nan).isBounded)
        #expect(!HeightRequest(width: 420, height: -1).isBounded)
        #expect(!HeightRequest(width: 420, height: 100_000).isBounded)
        #expect(HeightRequest(width: 420, height: 99_999).isBounded)
        #expect(HeightRequest.ceiling == 100_000)
    }

    @Test("narrowing the column is one stressor and a longer sentence is the other")
    func bothStressorsCountAsWrapping() {
        let narrowed = Self.comparison(said: [96], short: [96], reference: 32)
        #expect(narrowed.narrows)
        #expect(!narrowed.lengthens)
        #expect(narrowed.wraps)

        let lengthened = Self.comparison(said: [64], short: [32], reference: 64)
        #expect(!lengthened.narrows)
        #expect(lengthened.lengthens)
        #expect(lengthened.wraps)

        let neither = Self.comparison(said: [32], short: [32], reference: 32)
        #expect(!neither.wraps)

        let withinTolerance = Self.comparison(said: [33], short: [32], reference: 32)
        #expect(!withinTolerance.wraps)
        #expect(Self.comparison(said: [33.5], short: [32], reference: 32).wraps)
        #expect(HeightSweep.tolerance == 1)
    }

    @Test("a height that escaped is counted as wrapping, so the screen still gets asked")
    func anEscapedHeightIsNotSilentlyCleared() {
        let escaped = Self.comparison(said: [.infinity], short: [32], reference: 32)
        #expect(!escaped.isBounded)
        #expect(escaped.wraps)
        #expect(escaped.saying.unbounded.map(\.width) == [420])
    }

    @Test("a subject nothing was staged for is not read as a view that draws")
    func anEmptyStagingIsNotAPass() {
        let nothing = Self.comparison(said: [0], short: [0], reference: 0)
        #expect(!nothing.wasStaged)
        #expect(
            UnboundedHeightSubject.verdict(comparison: nothing, read: true, escaped: true)
                == .unmeasured
        )
    }

    @Test("a subject is only a release blocker once the height it asked for escaped")
    func theThreeBucketsTheIssueAsksFor() {
        let wrapping = Self.comparison(said: [96], short: [32], reference: 32)
        let onOneLine = Self.comparison(said: [32], short: [32], reference: 32)

        #expect(
            UnboundedHeightSubject.verdict(comparison: wrapping, read: true, escaped: true)
                == .emptiesTheWindow
        )
        #expect(
            UnboundedHeightSubject.verdict(comparison: wrapping, read: true, escaped: false) == .drawsAnyway
        )
        #expect(
            UnboundedHeightSubject.verdict(comparison: onOneLine, read: true, escaped: false) == .neverWraps
        )
        #expect(
            UnboundedHeightSubject.verdict(comparison: onOneLine, read: true, escaped: true)
                == .emptiesTheWindow
        )
    }

    @Test("a window grows past the floor on its height alone, whatever it is holding")
    func growingIsJudgedOnTheHeightAlone() {
        let floor = Self.floor
        let inky = WindowInk(onArrival: 0.0551, afterRedraw: 0.0551)
        #expect(DrawnWindow(ink: inky, height: 4_760).grew(past: floor))
        #expect(DrawnWindow(ink: inky, height: 1_477).grew(past: floor))
        #expect(!DrawnWindow(ink: inky, height: 1_476).grew(past: floor))
        #expect(!DrawnWindow(ink: inky, height: 984).grew(past: floor))
        #expect(DrawnWindow.growth == 1.5)
    }

    @Test("a window dims against itself on its ink alone, at the height the floor has")
    func dimmingIsJudgedOnTheInkAlone() {
        let short = DrawnWindow(ink: WindowInk(onArrival: 0.02, afterRedraw: 0.02), height: 984)
        let dark = DrawnWindow(ink: WindowInk(onArrival: 0.0149, afterRedraw: 0.0149), height: 984)
        #expect(dark.dimmed(against: short))
        #expect(!dark.grew(past: Self.floor))

        let lit = DrawnWindow(ink: WindowInk(onArrival: 0.015, afterRedraw: 0.015), height: 984)
        #expect(!lit.dimmed(against: short))
    }

    @Test("the archive card's own readings are what the two checks were built on")
    func theArchiveCardIsWhatTheRuleWasBuiltOn() {
        let bare = DrawnWindow(ink: WindowInk(onArrival: 0.0065, afterRedraw: 0.0065), height: 4_760)
        #expect(bare.grew(past: Self.floor))
        #expect(bare.dimmed(against: Self.floor))
        #expect(!Self.floor.grew(past: Self.floor))
        #expect(!Self.floor.dimmed(against: Self.floor))
    }

    @Test("a window that was never read cannot be said to have grown")
    func anUnreadWindowDecidesNothing() {
        #expect(!DrawnWindow().grew(past: Self.floor))
        #expect(!Self.floor.grew(past: DrawnWindow()))
        #expect(!Self.floor.dimmed(against: DrawnWindow()))
        #expect(!DrawnWindow().dimmed(against: Self.floor))
    }

    private static let floor = DrawnWindow(
        ink: WindowInk(onArrival: 0.0141, afterRedraw: 0.0141), height: 984
    )

    private static func comparison(
        said: [CGFloat], short: [CGFloat], reference: CGFloat
    ) -> HeightComparison {
        HeightComparison(
            saying: HeightSweep(
                reference: HeightRequest(width: 4_000, height: reference),
                atHostWidths: said.map { HeightRequest(width: 420, height: $0) }
            ),
            shortened: HeightSweep(
                reference: HeightRequest(width: 4_000, height: reference),
                atHostWidths: short.map { HeightRequest(width: 420, height: $0) }
            )
        )
    }

    @Test("a screen that was never read is not a view that draws")
    func anUnreadScreenIsNotAPass() {
        let wrapping = Self.comparison(said: [96], short: [32], reference: 32)
        #expect(
            UnboundedHeightSubject.verdict(comparison: wrapping, read: false, escaped: false)
                == .unmeasured
        )
        #expect(
            UnboundedHeightSubject.verdict(comparison: wrapping, read: false, escaped: true)
                == .unmeasured
        )
    }

    @Test("only the blank window stops the release")
    func onlyOneVerdictBlocksTheRelease() {
        let blocking = UnboundedHeightVerdict.allCases.filter(\.blocksRelease)
        #expect(blocking == [.emptiesTheWindow])
    }

    @Test("the sentence the probe feeds is long enough to be worth feeding")
    func theSentenceIsLongEnoughToWrap() {
        let said = UnboundedHeightSubject.longSentence
        #expect(said.count > 300)
        #expect(!said.unicodeScalars.contains { $0.value == 0x2014 || $0.value == 0x2013 })
        #expect(said.split(separator: " ").count > 60)
    }

    @Test("every host a subject lives in is one the probe knows how to open")
    func everyHostIsNamed() {
        let hosts = Set(UnboundedHeightSubject.all.map(\.host))
        #expect(hosts == Set(UnboundedHeightSubject.Host.allCases))
    }
}
