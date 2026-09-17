import Testing
import Foundation
@testable import Core

@Suite("The gap a markdown list puts between its items")
struct ListLeadingTests {
    @Test("prose list items have breathing room at the current defaults")
    func proseDefault() {
        let tight = ListLeading.betweenProseItems(
            tight: true, lineHeight: 18, pointSize: 15, ratio: ChatLineHeight.defaultChoice.ratio
        )
        let loose = ListLeading.betweenProseItems(
            tight: false, lineHeight: 18, pointSize: 15, ratio: ChatLineHeight.defaultChoice.ratio
        )
        #expect(tight == 8)
        #expect(loose == 13)
    }

    @Test("prose gaps follow every size and line-height preference without tightening wrapped lines")
    func prosePreferences() {
        for step in Self.bodySteps {
            for tight in [true, false] {
                var previous = 0.0
                for choice in ChatLineHeight.allCases {
                    let leading = TextLeading.overPointSize(
                        lineHeight: step.box, pointSize: step.size, ratio: choice.ratio
                    )
                    let gap = ListLeading.betweenProseItems(
                        tight: tight, lineHeight: step.box, pointSize: step.size, ratio: choice.ratio
                    )
                    #expect(gap > leading)
                    #expect(gap >= previous)
                    previous = gap
                }
            }
        }
    }

    private static let bodySteps: [(size: Double, box: Double)] = [
        (12, 15), (13, 16), (15, 18), (17, 20), (20, 23),
    ]

    private static func gaps(tight: Bool, size: Double, box: Double) -> [Double] {
        ChatLineHeight.allCases.map {
            ListLeading.betweenItems(
                tight: tight, lineHeight: box, pointSize: size, ratio: $0.listRatio
            )
        }
    }

    @Test("the default step lands back on the six points the view used to hard code")
    func theDefaultDoesNotMove() {
        let loose = ListLeading.betweenItems(
            tight: false, lineHeight: 16, pointSize: 13, ratio: ChatLineHeight.standard.listRatio
        )
        #expect(loose == 6)
    }

    @Test("the gap moves with the step wherever an item's own lines do")
    func theLineHeightReachesTheGaps() {
        for step in Self.bodySteps {
            let leadings = ChatLineHeight.allCases.map {
                TextLeading.overPointSize(
                    lineHeight: step.box, pointSize: step.size, ratio: $0.listRatio
                )
            }
            for tight in [true, false] {
                let points = Self.gaps(tight: tight, size: step.size, box: step.box)
                for index in points.indices.dropFirst() {
                    let gapOpened = points[index] > points[index - 1]
                    let lineOpened = leadings[index] > leadings[index - 1]
                    #expect(gapOpened == lineOpened)
                    #expect(points[index] >= points[index - 1])
                }
            }
        }
    }

    @Test("the ends of the control are apart at every text size")
    func theControlHasARangeEverywhere() {
        for step in Self.bodySteps {
            for tight in [true, false] {
                let points = Self.gaps(tight: tight, size: step.size, box: step.box)
                #expect(points.last! > points.first!)
            }
        }
    }

    @Test("the default text size answers one point a step tight, and two loose")
    func theDefaultSizeIsAnEvenLadder() {
        #expect(Self.gaps(tight: true, size: 13, box: 16) == [1, 2, 3, 4, 5])
        #expect(Self.gaps(tight: false, size: 13, box: 16) == [2, 4, 6, 8, 10])
    }

    @Test("a tight list stays tighter than a loose one, everywhere")
    func tightStaysTighterThanLoose() {
        for step in Self.bodySteps {
            for lineHeight in ChatLineHeight.allCases {
                let tight = ListLeading.betweenItems(
                    tight: true, lineHeight: step.box, pointSize: step.size,
                    ratio: lineHeight.listRatio
                )
                let loose = ListLeading.betweenItems(
                    tight: false, lineHeight: step.box, pointSize: step.size,
                    ratio: lineHeight.listRatio
                )
                #expect(tight < loose)
            }
        }
    }

    @Test("an item is never closer to the next item than to its own next line")
    func itemsAreNeverTighterThanTheirOwnLines() {
        for step in Self.bodySteps {
            for lineHeight in ChatLineHeight.allCases {
                let withinAnItem = TextLeading.overPointSize(
                    lineHeight: step.box, pointSize: step.size, ratio: lineHeight.listRatio
                )
                let betweenItems = ListLeading.betweenItems(
                    tight: true, lineHeight: step.box, pointSize: step.size,
                    ratio: lineHeight.listRatio
                )
                #expect(betweenItems >= withinAnItem)
            }
        }
    }

    @Test("a larger text size opens the gaps too")
    func theTextSizeReachesTheGapsAsWell() {
        for lineHeight in ChatLineHeight.allCases {
            let bySize = Self.bodySteps.map {
                ListLeading.betweenItems(
                    tight: false, lineHeight: $0.box, pointSize: $0.size, ratio: lineHeight.listRatio
                )
            }
            #expect(bySize.first! < bySize.last!)
        }
    }

    @Test("a font with no size at all gets no gap")
    func nothingToMeasureIsNoGap() {
        #expect(ListLeading.betweenItems(tight: false, lineHeight: 0, pointSize: 13, ratio: 1.45) == 0)
        #expect(ListLeading.betweenItems(tight: true, lineHeight: 16, pointSize: 0, ratio: 1.45) == 0)
    }
}
