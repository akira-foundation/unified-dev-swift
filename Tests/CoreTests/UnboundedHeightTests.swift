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

    @Test("a reading on either side of three quarters of Home falls on the right side of it")
    func theShareIsWhereTheRuleTurns() {
        let edge = Self.home.onArrival * WindowInk.share
        #expect(WindowInk(onArrival: edge, afterRedraw: edge).verdict(against: Self.home) == .drew)
        let under = WindowInk(onArrival: edge - 0.0001, afterRedraw: edge)
        #expect(under.verdict(against: Self.home) == .stoppedDrawing)
        let recovered = WindowInk(onArrival: edge, afterRedraw: edge - 0.0001)
        #expect(recovered.verdict(against: Self.home) == .stoppedDrawing)
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
        #expect(!HeightRequest(width: 420, height: HeightRequest.ceiling).isBounded)
        #expect(HeightRequest(width: 420, height: HeightRequest.ceiling - 1).isBounded)
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

        let withinTolerance = Self.comparison(
            said: [32 + HeightSweep.tolerance], short: [32], reference: 32
        )
        #expect(!withinTolerance.wraps)
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
            UnboundedHeightSubject.verdict(comparison: nothing, escaped: true) == .unmeasured
        )
    }

    @Test("a subject is only a release blocker once the height it asked for escaped")
    func theThreeBucketsTheIssueAsksFor() {
        let wrapping = Self.comparison(said: [96], short: [32], reference: 32)
        let onOneLine = Self.comparison(said: [32], short: [32], reference: 32)

        #expect(
            UnboundedHeightSubject.verdict(comparison: wrapping, escaped: true)
                == .emptiesTheWindow
        )
        #expect(
            UnboundedHeightSubject.verdict(comparison: wrapping, escaped: false) == .drawsAnyway
        )
        #expect(
            UnboundedHeightSubject.verdict(comparison: onOneLine, escaped: false) == .neverWraps
        )
        #expect(
            UnboundedHeightSubject.verdict(comparison: onOneLine, escaped: true)
                == .emptiesTheWindow
        )
    }

    @Test("the archive card's own readings are what tells an escaped height from a bounded one")
    func theArchiveCardIsWhatTheEscapeRuleWasBuiltOn() {
        let bare = DrawnWindow(ink: WindowInk(onArrival: 0.0065, afterRedraw: 0.0065), height: 4_760)
        let bounded = DrawnWindow(
            ink: WindowInk(onArrival: 0.0141, afterRedraw: 0.0141), height: 984
        )
        #expect(bare.letTheHeightEscape(against: bounded))
        #expect(!bounded.letTheHeightEscape(against: bounded))

        let tallButDrawing = DrawnWindow(
            ink: WindowInk(onArrival: 0.0230, afterRedraw: 0.0230), height: 1_200
        )
        #expect(!tallButDrawing.letTheHeightEscape(against: bounded))
    }

    @Test("a window that was never read cannot be said to have let a height escape")
    func anUnreadWindowDecidesNothing() {
        let bounded = DrawnWindow(
            ink: WindowInk(onArrival: 0.0141, afterRedraw: 0.0141), height: 984
        )
        #expect(!DrawnWindow().letTheHeightEscape(against: bounded))
        #expect(!bounded.letTheHeightEscape(against: DrawnWindow()))
    }

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
