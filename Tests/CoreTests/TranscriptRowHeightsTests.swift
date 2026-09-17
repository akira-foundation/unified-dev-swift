import Testing
import Foundation
@testable import Core

@Suite("Remembering how tall a transcript row is")
struct TranscriptRowHeightsTests {
    private func key(_ text: String) -> TranscriptContentKey {
        TranscriptContentKey { $0.combine(text) }
    }

    @Test("a row measured once is not measured again")
    func remembersAHeight() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7|assistant"), measuredAt: 800)
        #expect(heights.height(for: key("row.7|assistant")) == 120)
    }

    @Test("a row whose content moved is a different row")
    func contentIsPartOfTheKey() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7|folded"), measuredAt: 800)
        #expect(heights.height(for: key("row.7|unfolded")) == nil)
    }

    @Test("a change of width empties the cache")
    func widthInvalidates() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        let invalidated = heights.reset(width: 600, scale: 1, leading: 1.7)
        #expect(invalidated)
        #expect(heights.height(for: key("row.7")) == nil)
        #expect(heights.count == 0)
    }

    @Test("a change of text size empties the cache")
    func scaleInvalidates() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        let invalidated = heights.reset(width: 800, scale: 1.3, leading: 1.7)
        #expect(invalidated)
        #expect(heights.height(for: key("row.7")) == nil)
    }

    @Test("a change of line height empties the cache")
    func leadingInvalidates() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        let invalidated = heights.reset(width: 800, scale: 1, leading: 1.4)
        #expect(invalidated)
        #expect(heights.height(for: key("row.7")) == nil)
    }

    @Test("a resize carries the line height it was already at")
    func rewidthKeepsTheLeading() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.85)
        let moved = heights.rewidth(to: 600)
        #expect(moved)
        #expect(heights.measure?.leading == 1.85)
    }

    @Test("a width that comes back is not a width that was kept")
    func doesNotHoldEveryWidthItHasSeen() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        heights.reset(width: 600, scale: 1, leading: 1.7)
        heights.note(180, for: key("row.7"), measuredAt: 600)
        heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(heights.count == 0)
    }

    @Test("a fraction of a point is the same width")
    func toleratesAFraction() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831.5, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 831.5)
        let invalidated = heights.reset(width: 831.75, scale: 1, leading: 1.7)
        #expect(!invalidated)
        #expect(heights.height(for: key("row.7")) == 120)
    }

    @Test("a pass that changes nothing says so")
    func noChangeIsNotAnInvalidation() {
        var heights = TranscriptRowHeights()
        let firstPass = heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(firstPass)
        let secondPass = heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(!secondPass)
    }

    @Test("a width nothing can be drawn at is not a width")
    func refusesAnUnlaidPane() {
        var heights = TranscriptRowHeights()
        let atNought = heights.reset(width: 0, scale: 1, leading: 1.7)
        #expect(!atNought)
        let atOne = heights.reset(width: 1, scale: 1, leading: 1.7)
        #expect(!atOne)
        #expect(!heights.isReady)
    }

    @Test("nothing is remembered before a width has arrived")
    func refusesHeightsWithoutAWidth() {
        var heights = TranscriptRowHeights()
        let changed = heights.note(120, for: key("row.7"), measuredAt: 800)
        #expect(!changed)
        #expect(heights.height(for: key("row.7")) == nil)
    }

    @Test("the first real width makes the cache ready")
    func becomesReady() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 0, scale: 1, leading: 1.7)
        #expect(!heights.isReady)
        heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(heights.isReady)
    }

    @Test("what the row turned out to be outranks what was measured for it")
    func aDrawnRowWins() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        let changed = heights.note(340, for: key("row.7"), measuredAt: 800)
        #expect(changed)
        #expect(heights.height(for: key("row.7")) == 340)
    }

    @Test("a height that has not moved is not news")
    func ignoresAnUnchangedHeight() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        let changed = heights.note(120, for: key("row.7"), measuredAt: 800)
        #expect(changed)
        let changedAgain = heights.note(120, for: key("row.7"), measuredAt: 800)
        #expect(!changedAgain)
        let changedByAFraction = heights.note(119.6, for: key("row.7"), measuredAt: 800)
        #expect(!changedByAFraction)
    }

    @Test("nought is a real height and is kept")
    func nothingIsAnAnswer() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        let changed = heights.note(0, for: key("row.7"), measuredAt: 800)
        #expect(changed)
        #expect(heights.height(for: key("row.7")) == 0)
    }

    @Test("a height is rounded up, and never below nothing")
    func rounds() {
        #expect(TranscriptRowHeights.rounded(23.1) == 24)
        #expect(TranscriptRowHeights.rounded(24) == 24)
        #expect(TranscriptRowHeights.rounded(-3) == 0)
    }

    @Test("a resize keeps every height and marks it owed")
    func rewidthEstimates() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        let moved = heights.rewidth(to: 600)
        #expect(moved)
        #expect(heights.height(for: key("row.7")) == 120)
        #expect(heights.isStale(key("row.7")))
        #expect(heights.measure?.width == 600)
        #expect(heights.staleCount == 1)
    }

    @Test("a row measured again at the new width stops being owed one")
    func measuringClearsTheDebt() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        heights.rewidth(to: 600)
        heights.note(180, for: key("row.7"), measuredAt: 600)
        #expect(!heights.isStale(key("row.7")))
        #expect(heights.staleCount == 0)
    }

    @Test("a row that turns out the same height is still no longer owed one")
    func anUnchangedHeightStillSettlesTheDebt() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        heights.rewidth(to: 600)
        let changed = heights.note(120, for: key("row.7"), measuredAt: 600)
        #expect(!changed)
        #expect(!heights.isStale(key("row.7")))
    }

    @Test("a resize to the same width changes nothing")
    func rewidthToTheSameWidth() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        let rewidened = heights.rewidth(to: 800.25)
        #expect(!rewidened)
        #expect(!heights.isStale(key("row.7")))
    }

    @Test("a resize before a width has arrived is refused")
    func rewidthNeedsAWidth() {
        var heights = TranscriptRowHeights()
        let rewidened = heights.rewidth(to: 800)
        #expect(!rewidened)
        #expect(!heights.isReady)
        heights.reset(width: 800, scale: 1, leading: 1.7)
        let rewidened2 = heights.rewidth(to: 1)
        #expect(!rewidened2)
        #expect(heights.measure?.width == 800)
    }

    @Test("a text size change empties what a resize would have kept")
    func resetClearsTheDebt() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        heights.rewidth(to: 600)
        heights.reset(width: 600, scale: 1.3, leading: 1.7)
        #expect(heights.staleCount == 0)
        #expect(heights.height(for: key("row.7")) == nil)
    }

    @Test("forgetting settles every debt a resize left")
    func forgettingClearsTheDebt() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        heights.rewidth(to: 600)
        heights.forget()
        #expect(heights.staleCount == 0)
        #expect(!heights.isStale(key("row.7")))
    }

    @Test("a row nobody has measured is assumed rather than refused")
    func assumesAnUnmeasuredRow() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(heights.height(for: key("row.7")) == nil)
        #expect(heights.assumed(for: key("row.7")) == TranscriptRowHeights.assumedRowHeight)
    }

    @Test("what has been measured is what the rest is assumed to be")
    func assumesTheMiddleOfWhatIsKnown() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        heights.note(200, for: key("row.2"), measuredAt: 800)
        #expect(heights.estimate == 100)
        #expect(heights.assumed(for: key("row.99")) == 100)
        #expect(heights.assumed(for: key("row.1")) == 100)
    }

    @Test("a row measured at nothing is known to draw nothing")
    func measuredNothingIsNothing() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(0, for: key("blank"), measuredAt: 800)
        #expect(heights.measuredNothing(key("blank")))
    }

    @Test("a stale empty measurement cannot prevent a row being drawn after resizing")
    func staleNothingIsNotEvidence() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(0, for: key("row"), measuredAt: 800)
        heights.rewidth(to: 600)
        #expect(!heights.measuredNothing(key("row")))
        #expect(heights.needsMeasuring(key("row"), redrawsItself: false))

        heights.note(0, for: key("row"), measuredAt: 800)
        #expect(!heights.measuredNothing(key("row")))
        heights.note(24, for: key("row"), measuredAt: 600)
        #expect(heights.height(for: key("row")) == 24)
        #expect(!heights.needsMeasuring(key("row"), redrawsItself: false))
    }

    @Test("a row still empty at the new width can be silenced again")
    func confirmsNothingAtTheNewWidth() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(0, for: key("row"), measuredAt: 800)
        heights.rewidth(to: 600)
        let changed = heights.note(0, for: key("row"), measuredAt: 600)
        #expect(!changed)
        #expect(heights.measuredNothing(key("row")))
        #expect(!heights.isStale(key("row")))
    }

    @Test("a row nobody has measured is not known to draw nothing")
    func unmeasuredIsNotNothing() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(!heights.measuredNothing(key("never.drawn")))
        #expect(heights.assumed(for: key("never.drawn"), drawsNothing: true) == 0)
        #expect(!heights.measuredNothing(key("never.drawn")))
    }

    @Test("anything at all is not nothing")
    func somethingIsNotNothing() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(24, for: key("row.1"), measuredAt: 800)
        heights.note(0.4, for: key("row.2"), measuredAt: 800)
        #expect(!heights.measuredNothing(key("row.1")))
        #expect(!heights.measuredNothing(key("row.2")))
        #expect(heights.height(for: key("row.2")) == 1)
    }

    @Test("a row that gains content is not the row that drew nothing")
    func gainingContentMissesTheCache() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(0, for: key("row.7.empty"), measuredAt: 800)
        #expect(heights.measuredNothing(key("row.7.empty")))
        #expect(!heights.measuredNothing(key("row.7.full")))
    }

    @Test("emptying the cache stops any row being known to draw nothing")
    func forgettingUnsilencesEverything() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(0, for: key("blank"), measuredAt: 800)
        heights.forget()
        #expect(!heights.measuredNothing(key("blank")))
    }

    @Test("a row that draws nothing is worth nothing before it is drawn")
    func assumesNothingForABlankRow() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        #expect(heights.assumed(for: key("blank"), drawsNothing: true) == 0)
        #expect(heights.assumed(for: key("blank")) == 100)
    }

    @Test("a measurement outranks the claim that a row draws nothing")
    func measurementBeatsTheClaim() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(42, for: key("row.1"), measuredAt: 800)
        #expect(heights.assumed(for: key("row.1"), drawsNothing: true) == 42)
    }

    @Test("rows that drew nothing do not drag the estimate down")
    func noughtsAreNotInTheMean() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        heights.note(200, for: key("row.2"), measuredAt: 800)
        for row in 0..<50 { heights.note(0, for: key("blank.\(row)"), measuredAt: 800) }
        #expect(heights.estimate == 100)
        #expect(heights.height(for: key("blank.7")) == 0)
        #expect(heights.count == 52)
    }

    @Test("a row that becomes nothing leaves the mean")
    func aRowThatEmptiesLeavesTheMean() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        heights.note(300, for: key("row.2"), measuredAt: 800)
        heights.note(0, for: key("row.2"), measuredAt: 800)
        #expect(heights.estimate == 100)
    }

    @Test("the estimate settles and then holds still")
    func settlesAndHolds() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(100, for: key("row.\(row)"), measuredAt: 800)
        }
        #expect(heights.estimate == 100)
        for row in 0..<23 { heights.note(900, for: key("late.\(row)"), measuredAt: 800) }
        #expect(heights.estimate == 100)
        #expect(heights.assumed(for: key("never.drawn")) == 100)
    }

    @Test("a settled estimate formed off a bad screenful is taken again")
    func resettlesWhenItIsBadlyOut() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(400, for: key("tail.\(row)"), measuredAt: 800)
        }
        #expect(heights.estimate == 400)
        for row in 0..<23 { heights.note(20, for: key("row.\(row)"), measuredAt: 800) }
        #expect(heights.estimate == 400)
        heights.note(20, for: key("row.23"), measuredAt: 800)
        #expect(heights.estimate == 20)
    }

    @Test("a settled estimate that is nearly right is left alone")
    func doesNotResettleForSmallDrift() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(100, for: key("row.\(row)"), measuredAt: 800)
        }
        #expect(heights.estimate == 100)
        for row in 0..<400 { heights.note(110, for: key("more.\(row)"), measuredAt: 800) }
        #expect(heights.estimate == 100)
    }

    @Test("the estimate tracks until it settles")
    func tracksUntilItSettles() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        #expect(heights.estimate == 100)
        heights.note(300, for: key("row.2"), measuredAt: 800)
        #expect(heights.estimate == 100)
    }

    @Test("emptying the cache unsettles the estimate")
    func settlingIsEmptiedWithTheCache() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(100, for: key("row.\(row)"), measuredAt: 800)
        }
        heights.forget()
        #expect(heights.estimate == TranscriptRowHeights.assumedRowHeight)
        heights.note(40, for: key("fresh"), measuredAt: 800)
        #expect(heights.estimate == 40)
    }

    @Test("noughts do not settle the estimate")
    func noughtsDoNotSettleIt() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<200 { heights.note(0, for: key("blank.\(row)"), measuredAt: 800) }
        heights.note(100, for: key("row.1"), measuredAt: 800)
        #expect(heights.estimate == 100)
        heights.note(300, for: key("row.2"), measuredAt: 800)
        #expect(heights.estimate == 100)
    }

    @Test("a row measured again does not count twice")
    func meanFollowsAnOverwrite() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        heights.note(300, for: key("row.1"), measuredAt: 800)
        #expect(heights.estimate == 300)
    }

    @Test("a cache that has been emptied assumes nothing it used to know")
    func meanIsEmptiedWithTheCache() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(400, for: key("row.1"), measuredAt: 800)
        heights.forget()
        #expect(heights.estimate == TranscriptRowHeights.assumedRowHeight)
    }

    @Test("a resize keeps the estimate as well as the heights")
    func meanSurvivesAResize() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        heights.note(200, for: key("row.2"), measuredAt: 800)
        heights.rewidth(to: 600)
        #expect(heights.estimate == 100)
    }

    @Test("the conversation being left does not say how tall the arriving one's rows are")
    func theEstimateDoesNotCrossAWorkspaceSwitch() {
        var heights = TranscriptRowHeights()
        heights.showing(SessionID("prose"))
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<2_000 { heights.note(400, for: key("prose.\(row)"), measuredAt: 800) }
        #expect(heights.estimate == 400)

        let switched = heights.showing(SessionID("tools"))
        #expect(switched)
        #expect(heights.assumed(for: key("tools.0")) == TranscriptRowHeights.assumedRowHeight)
    }

    @Test("the estimate settles again for the conversation arriving")
    func theEstimateSettlesForEachConversation() {
        var heights = TranscriptRowHeights()
        heights.showing(SessionID("prose"))
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<2_000 { heights.note(400, for: key("prose.\(row)"), measuredAt: 800) }
        heights.showing(SessionID("tools"))
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(24, for: key("tools.\(row)"), measuredAt: 800)
        }
        #expect(heights.estimate == 24)
        #expect(heights.assumed(for: key("tools.never.drawn")) == 24)
    }

    @Test("a switch keeps every height that was measured")
    func aSwitchKeepsTheHeights() {
        var heights = TranscriptRowHeights()
        heights.showing(SessionID("one"))
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("one.row.7"), measuredAt: 800)
        heights.showing(SessionID("two"))
        #expect(heights.height(for: key("one.row.7")) == 120)
        let back = heights.showing(SessionID("one"))
        #expect(back)
        #expect(heights.height(for: key("one.row.7")) == 120)
    }

    @Test("rows the cache already knows still form the estimate")
    func aReturningConversationFormsItsOwnEstimate() {
        var heights = TranscriptRowHeights()
        heights.showing(SessionID("one"))
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(300, for: key("one.\(row)"), measuredAt: 800)
        }
        heights.showing(SessionID("two"))
        let back = heights.showing(SessionID("one"))
        #expect(back)
        #expect(heights.estimate == TranscriptRowHeights.assumedRowHeight)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(300, for: key("one.\(row)"), measuredAt: 800)
        }
        #expect(heights.estimate == 300)
    }

    @Test("a row that reports twice is in the sample once")
    func aRowIsSampledOnce() {
        var heights = TranscriptRowHeights()
        heights.showing(SessionID("one"))
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(100, for: key("row.1"), measuredAt: 800)
        for step in 1...20 { heights.note(Double(100 + step * 10), for: key("tail"), measuredAt: 800) }
        #expect(heights.estimate == 100)
    }

    @Test("saying the same conversation again changes nothing")
    func sayingTheSameConversationIsIdempotent() {
        var heights = TranscriptRowHeights()
        heights.showing(SessionID("one"))
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(300, for: key("one.\(row)"), measuredAt: 800)
        }
        let again = heights.showing(SessionID("one"))
        #expect(!again)
        #expect(heights.estimate == 300)
    }

    @Test("a cache that has grown past its bound starts again")
    func boundsWhatItRemembers() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.mostRows {
            heights.note(Double(row % 400) + 1, for: key("row.\(row)"), measuredAt: 800)
        }
        #expect(heights.count == TranscriptRowHeights.mostRows)
        heights.note(120, for: key("one.too.many"), measuredAt: 800)
        #expect(heights.count == 1)
        #expect(heights.height(for: key("one.too.many")) == 120)
        #expect(heights.measure?.width == 800)
    }

    @Test("a row already remembered is not what pushes the cache over")
    func anUpdateIsNotAnInsert() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.mostRows {
            heights.note(Double(row % 400) + 1, for: key("row.\(row)"), measuredAt: 800)
        }
        heights.note(999, for: key("row.0"), measuredAt: 800)
        #expect(heights.count == TranscriptRowHeights.mostRows)
        #expect(heights.height(for: key("row.0")) == 999)
    }

    @Test("half a point is the same height, and it is the slack a note is filed under")
    func oneRuleAboutTheSameHeight() {
        #expect(TranscriptRowHeights.isSameHeight(24, 24.4))
        #expect(!TranscriptRowHeights.isSameHeight(24, 25))
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(24, for: key("row.1"), measuredAt: 800)
        let news = heights.note(24.4, for: key("row.1"), measuredAt: 800)
        #expect(news)
        let again = heights.note(25, for: key("row.1"), measuredAt: 800)
        #expect(!again)
    }

    @Test("half a point is the same width, and one answer says so")
    func oneRuleAboutTheSameWidth() {
        #expect(TranscriptRowHeights.isSameWidth(831.5, 831.75))
        #expect(!TranscriptRowHeights.isSameWidth(831.5, 833))
    }

    @Test("a row nobody has measured is owed one")
    func anUnknownRowIsOwed() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(heights.needsMeasuring(key("row.7"), redrawsItself: false))
    }

    @Test("a stored row that has been measured is not owed another")
    func aMeasuredRowIsNotOwed() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        #expect(!heights.needsMeasuring(key("row.7"), redrawsItself: false))
    }

    @Test("a row measured at another width is owed another")
    func aStaleRowIsOwed() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        let moved = heights.rewidth(to: 600)
        #expect(moved)
        #expect(heights.needsMeasuring(key("row.7"), redrawsItself: false))
    }

    @Test("an entry that redraws itself is always owed a measurement")
    func anEntryThatRedrawsItselfIsAlwaysOwed() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(480, for: key("streaming.session-a"), measuredAt: 800)
        #expect(heights.height(for: key("streaming.session-a")) == 480)
        #expect(heights.needsMeasuring(key("streaming.session-a"), redrawsItself: true))
    }

    @Test("a fold's line is answered from its key, like the row it stands over")
    func aFoldIsAnsweredFromItsKey() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        let fold = TranscriptEntryID.fold(41)
        heights.note(0, for: key("fold.41|shows-nothing"), measuredAt: 800)
        #expect(!fold.redrawsItself)
        #expect(!heights.needsMeasuring(key("fold.41|shows-nothing"), redrawsItself: fold.redrawsItself))
    }

    @Test("a visible row nobody has measured is worth putting right on its own")
    func aGuessIsWorthRepairing() {
        #expect(TranscriptRowHeights.needsRepair(guessed: 1, wrong: 0))
    }

    @Test("and so is the table disagreeing with the cache")
    func aDisagreementIsWorthRepairing() {
        #expect(TranscriptRowHeights.needsRepair(guessed: 0, wrong: 3))
    }

    @Test("a screen that is right is left alone")
    func aRightScreenIsLeftAlone() {
        #expect(!TranscriptRowHeights.needsRepair(guessed: 0, wrong: 0))
    }

    @Test("nothing is owed before a width has arrived, because nothing has been measured")
    func everythingIsOwedBeforeAWidth() {
        let heights = TranscriptRowHeights()
        #expect(heights.needsMeasuring(key("row.7"), redrawsItself: false))
    }

    @Test("forgetting empties the cache and keeps the width")
    func forgets() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 800, scale: 1, leading: 1.7)
        heights.note(120, for: key("row.7"), measuredAt: 800)
        heights.forget()
        #expect(heights.height(for: key("row.7")) == nil)
        #expect(heights.isReady)
        let invalidated = heights.reset(width: 800, scale: 1, leading: 1.7)
        #expect(!invalidated)
    }

    @Test("a head grow tells a fold what a fold is, not what the newest answer was")
    func aHeadGrowIsToldItsOwnShape() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        heights.showing(SessionID("chat"))
        for fold in 0..<3 { heights.note(28, for: key("fold.\(fold)"), shape: .fold, measuredAt: 831) }
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(800, for: key("answer.\(row)"), shape: .answer, measuredAt: 831)
        }
        #expect(heights.estimate == TranscriptRowHeights.mostEstimated)
        var blank = 0.0
        for fold in 3..<15 {
            blank += heights.assumed(for: key("fold.\(fold)"), shape: .fold) - 28
        }
        #expect(blank == 0)
        var wasBlank = 0.0
        for fold in 3..<15 {
            wasBlank += heights.assumed(for: key("fold.\(fold)")) - 28
        }
        #expect(wasBlank == 5_064)
    }

    @Test("a shape nobody has measured enough of falls back to the conversation")
    func tooLittleOfAShapeFallsBack() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<10 { heights.note(200, for: key("answer.\(row)"), shape: .answer, measuredAt: 831) }
        heights.note(28, for: key("fold.1"), shape: .fold, measuredAt: 831)
        heights.note(28, for: key("fold.2"), shape: .fold, measuredAt: 831)
        #expect(heights.estimate(for: .fold) == 200)
        heights.note(28, for: key("fold.3"), shape: .fold, measuredAt: 831)
        #expect(heights.estimate(for: .fold) == 28)
    }

    @Test("a shape's rows still form the conversation's own mean")
    func shapesStillFeedTheWholeConversation() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        heights.note(100, for: key("a"), shape: .tool, measuredAt: 831)
        heights.note(300, for: key("b"), shape: .answer, measuredAt: 831)
        #expect(heights.estimate == 100)
    }

    @Test("an unclassified row is answered by the conversation's own mean")
    func otherIsTheConversation() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<10 { heights.note(40, for: key("tool.\(row)"), shape: .tool, measuredAt: 831) }
        heights.note(900, for: key("tail"), shape: .other, measuredAt: 831)
        #expect(heights.estimate(for: .other) == heights.estimate)
        #expect(heights.estimate == 40)
    }

    @Test("a shape's estimate settles and then holds still")
    func aShapeSettlesAndHolds() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleShapeAfter {
            heights.note(30, for: key("tool.\(row)"), shape: .tool, measuredAt: 831)
        }
        #expect(heights.estimate(for: .tool) == 30)
        heights.note(300, for: key("tool.wide.1"), shape: .tool, measuredAt: 831)
        heights.note(300, for: key("tool.wide.2"), shape: .tool, measuredAt: 831)
        #expect(heights.estimate(for: .tool) == 30)
    }

    @Test("a shape's estimate is taken again once its sample has doubled and it is far out")
    func aShapeResettles() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<3 { heights.note(300, for: key("tool.\(row)"), shape: .tool, measuredAt: 831) }
        #expect(heights.estimate(for: .tool) == 300)
        for row in 3..<6 { heights.note(30, for: key("tool.\(row)"), shape: .tool, measuredAt: 831) }
        #expect(heights.estimate(for: .tool) == 30)
    }

    @Test("a shape that is nearly right is left alone")
    func aShapeDoesNotResettleForSmallDrift() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<3 { heights.note(100, for: key("fold.\(row)"), shape: .fold, measuredAt: 831) }
        for row in 3..<40 { heights.note(105, for: key("fold.\(row)"), shape: .fold, measuredAt: 831) }
        #expect(heights.estimate(for: .fold) == 100)
    }

    @Test("rows that drew nothing do not form a shape's estimate")
    func noughtsDoNotFormAShape() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<50 { heights.note(0, for: key("blank.\(row)"), shape: .tool, measuredAt: 831) }
        for row in 0..<3 { heights.note(40, for: key("tool.\(row)"), shape: .tool, measuredAt: 831) }
        #expect(heights.estimate(for: .tool) == 40)
    }

    @Test("a row measured again does not count twice in its shape")
    func aShapeFollowsAnOverwrite() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<2 { heights.note(40, for: key("tool.\(row)"), shape: .tool, measuredAt: 831) }
        heights.note(100, for: key("tool.0"), shape: .tool, measuredAt: 831)
        heights.note(40, for: key("tool.2"), shape: .tool, measuredAt: 831)
        #expect(heights.estimate(for: .tool) == 40)
    }

    @Test("pointing the pane elsewhere starts every shape again")
    func showingStartsEveryShapeAgain() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        heights.showing(SessionID("prose"))
        for row in 0..<3 { heights.note(900, for: key("answer.\(row)"), shape: .answer, measuredAt: 831) }
        #expect(heights.estimate(for: .answer) == TranscriptRowHeights.mostEstimated)
        heights.showing(SessionID("tools"))
        #expect(heights.estimate(for: .answer) == TranscriptRowHeights.assumedRowHeight)
    }

    @Test("a resize keeps the shapes as well as the heights")
    func shapesSurviveAResize() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<3 { heights.note(30, for: key("tool.\(row)"), shape: .tool, measuredAt: 831) }
        heights.rewidth(to: 600)
        #expect(heights.estimate(for: .tool) == 30)
    }

    @Test("emptying the cache empties every shape")
    func forgettingEmptiesTheShapes() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 831, scale: 1, leading: 1.7)
        for row in 0..<3 { heights.note(30, for: key("tool.\(row)"), shape: .tool, measuredAt: 831) }
        heights.forget()
        #expect(heights.estimate(for: .tool) == TranscriptRowHeights.assumedRowHeight)
    }

    @Test("a height reported at another width is not news about this one")
    func aReportAtAnotherWidthIsRefused() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        heights.note(54, for: key("row.19554"), measuredAt: 420)
        let took = heights.note(1_972, for: key("row.19554"), measuredAt: 15)
        #expect(!took)
        #expect(heights.height(for: key("row.19554")) == 54)
    }

    @Test("a spike from a narrow pass does not reach the estimate either")
    func aReportAtAnotherWidthDoesNotMoveTheEstimate() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        for row in 0..<3 {
            heights.note(444, for: key("message.\(row)"), shape: .message, measuredAt: 420)
        }
        #expect(heights.estimate(for: .message) == 444)
        heights.note(10_806, for: key("message.3"), shape: .message, measuredAt: 17)
        #expect(heights.estimate(for: .message) == 444)
        #expect(heights.assumed(for: key("message.unseen"), shape: .message) == 444)
    }

    @Test("the row that was caught: 2,568 points from a layout 24 points wide")
    func theRowThatWasCaught() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        heights.note(75, for: key("row.2593"), shape: .answer, measuredAt: 420)
        let took = heights.note(2_568, for: key("row.2593"), shape: .answer, measuredAt: 24)
        #expect(!took)
        #expect(heights.height(for: key("row.2593")) == 75)
        #expect(heights.estimate(for: .answer) == 75)
    }

    @Test("a height reported at this width is news")
    func aReportAtThisWidthIsKept() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        let took = heights.note(120, for: key("row.7"), measuredAt: 420)
        #expect(took)
        #expect(heights.height(for: key("row.7")) == 120)
    }

    @Test("a fraction of a point is the same width")
    func aFractionIsTheSameWidth() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        let took = heights.note(120, for: key("row.7"), measuredAt: 419.75)
        #expect(took)
    }

    @Test("a refused row is measured by the next report at the right width")
    func aRefusedRowIsMeasuredOnTheNextPass() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        heights.note(9_000, for: key("row.7"), measuredAt: 15)
        #expect(heights.height(for: key("row.7")) == nil)
        heights.note(120, for: key("row.7"), measuredAt: 420)
        #expect(heights.height(for: key("row.7")) == 120)
    }

    @Test("the rule, said on its own")
    func theEvidenceRule() {
        #expect(TranscriptRowHeights.isEvidence(measuredAt: 420, forCacheAt: 420))
        #expect(TranscriptRowHeights.isEvidence(measuredAt: 419.75, forCacheAt: 420))
        #expect(!TranscriptRowHeights.isEvidence(measuredAt: 15, forCacheAt: 420))
        #expect(!TranscriptRowHeights.isEvidence(measuredAt: 420, forCacheAt: 747))
        #expect(!TranscriptRowHeights.isEvidence(measuredAt: 420, forCacheAt: nil))
    }

    @Test("one enormous row does not decide what every other row is")
    func aTailDoesNotDecideTheEstimate() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        heights.showing(SessionID("his"))
        heights.note(40, for: key("answer.1"), shape: .answer, measuredAt: 420)
        heights.note(60, for: key("answer.2"), shape: .answer, measuredAt: 420)
        heights.note(10_806, for: key("answer.3"), shape: .answer, measuredAt: 420)
        #expect(heights.estimate(for: .answer) == 60)
        #expect(heights.assumed(for: key("answer.unseen"), shape: .answer) == 60)
        #expect(heights.assumed(for: key("answer.3"), shape: .answer) == 10_806)
    }

    @Test("the rows nobody has measured do not add up to a document of fiction")
    func aDocumentOfEstimatesIsNotFiction() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        heights.showing(SessionID("his"))
        heights.note(40, for: key("answer.1"), shape: .answer, measuredAt: 420)
        heights.note(60, for: key("answer.2"), shape: .answer, measuredAt: 420)
        heights.note(10_806, for: key("answer.3"), shape: .answer, measuredAt: 420)
        var document = 0.0
        for row in 0..<2_242 {
            document += heights.assumed(for: key("above.\(row)"), shape: .answer)
        }
        #expect(document == 134_520)
    }

    @Test("no row nobody has looked at may fill the screen on its own")
    func theGuessIsBounded() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(6_025, for: key("answer.\(row)"), shape: .answer, measuredAt: 420)
        }
        #expect(heights.estimate == TranscriptRowHeights.mostEstimated)
        #expect(heights.estimate(for: .answer) == TranscriptRowHeights.mostEstimated)
        #expect(
            heights.assumed(for: key("unseen"), shape: .answer)
                == TranscriptRowHeights.mostEstimated
        )
    }

    @Test("a measured row is its own height however tall it is")
    func theBoundIsOnlyOnTheGuess() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        heights.note(6_025, for: key("answer.1"), shape: .answer, measuredAt: 420)
        #expect(heights.height(for: key("answer.1")) == 6_025)
        #expect(heights.assumed(for: key("answer.1"), shape: .answer) == 6_025)
    }

    @Test("the bound does not touch an estimate that is already sensible")
    func theBoundLeavesASensibleEstimateAlone() {
        var heights = TranscriptRowHeights()
        heights.reset(width: 420, scale: 1, leading: 1.7)
        for row in 0..<TranscriptRowHeights.settleAfter {
            heights.note(24, for: key("row.\(row)"), measuredAt: 420)
        }
        #expect(heights.estimate == 24)
    }
}
