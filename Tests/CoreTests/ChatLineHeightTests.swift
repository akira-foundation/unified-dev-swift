import Testing
import Foundation
@testable import Core

@Suite("The steps the conversation's line height is set in")
struct ChatLineHeightTests {
    private static let bodySteps: [(size: Double, box: Double)] = [
        (12, 15), (13, 16), (15, 18), (17, 20), (20, 23),
    ]

    @Test("the new default leaves the old middle step unchanged")
    func theDefaultPreservesExistingSteps() {
        #expect(ChatLineHeight.standard.ratio == 1.7)
        #expect(ChatLineHeight.defaultChoice == .tighter)
        #expect(TextLeading.proseRatio == 1.55)
        #expect(ChatLineHeight.allCases.count == 5)
        #expect(ChatLineHeight.allCases[2] == .standard)
    }

    @Test("every step is a different number of points from its neighbour, at every text size")
    func neighboursAreVisiblyApart() {
        for step in Self.bodySteps {
            let points = ChatLineHeight.allCases.map {
                TextLeading.overPointSize(
                    lineHeight: step.box, pointSize: step.size, ratio: $0.ratio
                )
            }
            for (tighter, looser) in zip(points, points.dropFirst()) {
                #expect(looser > tighter)
            }
        }
    }

    @Test("the original 13 point size still answers two points a step, from two to ten")
    func theOriginalSizeIsAnEvenLadder() {
        let points = ChatLineHeight.allCases.map {
            TextLeading.overPointSize(lineHeight: 16, pointSize: 13, ratio: $0.ratio)
        }
        #expect(points == [2, 4, 6, 8, 10])
    }

    @Test("the range runs from dense to airy and stops there")
    func theEndsAreWhereTheyWereChosen() {
        #expect(ChatLineHeight.allCases.first?.ratio == 1.4)
        #expect(ChatLineHeight.allCases.last?.ratio == 2)
    }

    @Test("the steps are ordered, evenly, tightest first")
    func theLadderIsEven() {
        let ratios = ChatLineHeight.allCases.map(\.ratio)
        let gaps = zip(ratios, ratios.dropFirst()).map { $1 - $0 }
        for gap in gaps {
            #expect(abs(gap - 0.15) < 0.0001)
        }
    }

    @Test("a step survives the round trip through its raw value")
    func rawValuesRoundTrip() {
        for step in ChatLineHeight.allCases {
            #expect(ChatLineHeight(rawValue: step.rawValue) == step)
        }
        #expect(ChatLineHeight.defaultsKey == "chat.lineHeight")
    }

    @Test("every step has a name of its own")
    func titlesAreDistinct() {
        let titles = ChatLineHeight.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
        #expect(ChatLineHeight.defaultChoice.title == "Default")
    }

    @Test("the code ratio is not on this ladder")
    func codeIsNotMoved() {
        #expect(!ChatLineHeight.allCases.map(\.ratio).contains(TextLeading.codeRatio))
        #expect(TextLeading.overLineBox(lineHeight: 13) == 4)
    }

    @Test("wrapped list lines stay compact while following the setting")
    func listsUseATighterLadder() {
        let ratios = ChatLineHeight.allCases.map(\.listRatio)

        for (actual, expected) in zip(ratios, [1.3, 1.375, 1.45, 1.525, 1.6]) {
            #expect(abs(actual - expected) < 0.0001)
        }
        #expect(ChatLineHeight.standard.listRatio < ChatLineHeight.standard.ratio)
        for (tighter, looser) in zip(ratios, ratios.dropFirst()) {
            #expect(looser > tighter)
        }
    }
}
