import Testing
import Foundation
@testable import Core

@Suite("How a run of transcript prose says how big it is")
struct TranscriptTextMeasureTests {
    @Test("bubble alignment balances actual ink on both single and multiple lines")
    func bubbleAlignment() {
        for (height, top, bottom) in [(17.0, 4.0, 16.0), (61.0, 4.0, 60.0), (17.0, 3.0, 14.0)] {
            let offset = TranscriptTextMeasure.bubbleTextOffset(height: height, inkTop: top, inkBottom: bottom)
            #expect(top + offset == height - bottom - offset)
            #expect(top + offset >= 0 && bottom + offset <= height)
        }
        #expect(TranscriptTextMeasure.bubbleTextOffset(height: 0, inkTop: 0, inkBottom: 0) == 0)
        #expect(TranscriptTextMeasure.bubbleTextOffset(height: .infinity, inkTop: 4, inkBottom: 16) == 0)
        #expect(TranscriptTextMeasure.bubbleTextOffset(height: 17, inkTop: -1, inkBottom: 16) == 0)
        #expect(TranscriptTextMeasure.bubbleTextOffset(height: 17, inkTop: 1, inkBottom: 18) == 0)
    }

    @Test("a real proposal is what the run is laid out at")
    func finiteProposal() {
        #expect(TranscriptTextMeasure.layoutWidth(proposed: 456) == 456)
        #expect(TranscriptTextMeasure.layoutWidth(proposed: 1.5) == 1.5)
    }

    @Test("no proposal at all is a question about the ideal size, and gets one")
    func unspecifiedProposal() {
        #expect(TranscriptTextMeasure.layoutWidth(proposed: nil) == TranscriptTextMeasure.idealWidth)
        #expect(TranscriptTextMeasure.layoutWidth(proposed: .infinity) == TranscriptTextMeasure.idealWidth)
        #expect(TranscriptTextMeasure.idealWidth.isFinite)
    }

    @Test("a proposal of nothing is asked at a hair's width rather than at zero")
    func zeroProposal() {
        #expect(TranscriptTextMeasure.layoutWidth(proposed: 0) == TranscriptTextMeasure.floorWidth)
        #expect(TranscriptTextMeasure.layoutWidth(proposed: -20) == TranscriptTextMeasure.floorWidth)
        #expect(TranscriptTextMeasure.floorWidth > 0)
    }

    @Test("a short run hugs its own words rather than the room it was offered")
    func hugsItsWords() {
        let size = TranscriptTextMeasure.size(
            widestLine: 52.4, usedHeight: 16, proposed: 456, lineHeight: 16, hasGlyphs: true
        )
        #expect(size == TranscriptTextMeasure.Size(width: 53, height: 16))
    }

    @Test("a run may not report itself wider than the room it was offered")
    func cappedByTheProposal() {
        let size = TranscriptTextMeasure.size(
            widestLine: 455.8, usedHeight: 64, proposed: 456, lineHeight: 16, hasGlyphs: true
        )
        #expect(size.width == 456)
        #expect(size.height == 64)
    }

    @Test("an ideal size is not capped, because nothing offered any room")
    func idealSizeIsNotCapped() {
        let size = TranscriptTextMeasure.size(
            widestLine: 2_400, usedHeight: 16, proposed: nil, lineHeight: 16, hasGlyphs: true
        )
        #expect(size.width == 2_400)
    }

    @Test("an empty run takes no space, so an empty paragraph costs no line")
    func emptyRun() {
        let size = TranscriptTextMeasure.size(
            widestLine: 0, usedHeight: 0, proposed: 456, lineHeight: 16, hasGlyphs: false
        )
        #expect(size == TranscriptTextMeasure.Size(width: 0, height: 0))
    }

    @Test("a run holding words never reports a size that would draw nothing", arguments: [
        (0.0, 0.0),
        (0.0, 35.0),
        (589.0, 0.0),
        (-4.0, -4.0),
    ])
    func neverReportsNothing(widestLine: Double, usedHeight: Double) {
        let size = TranscriptTextMeasure.size(
            widestLine: widestLine, usedHeight: usedHeight,
            proposed: 592, lineHeight: 16, hasGlyphs: true
        )
        #expect(size.width > 0, "a run with words in it reported a width of \(size.width)")
        #expect(size.height > 0, "a run with words in it reported a height of \(size.height)")
    }

    @Test("the floor holds when nothing was proposed either")
    func theFloorHoldsWithoutAProposal() {
        let size = TranscriptTextMeasure.size(
            widestLine: 0, usedHeight: 0, proposed: nil, lineHeight: 16, hasGlyphs: true
        )
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test("a run that drew no ink reports a hair's width, not the scratch measure it was laid out in")
    func inkFreeRunDoesNotReportTheScratchWidth() {
        let size = TranscriptTextMeasure.size(
            widestLine: 0, usedHeight: 32, proposed: nil, lineHeight: 16, hasGlyphs: true
        )
        #expect(size.width == TranscriptTextMeasure.floorWidth)
        #expect(size.height == 32)
    }

    @Test("a run that drew no ink falls back to the room it was offered")
    func inkFreeRunFallsBackToTheProposal() {
        let size = TranscriptTextMeasure.size(
            widestLine: 0, usedHeight: 32, proposed: 456, lineHeight: 16, hasGlyphs: true
        )
        #expect(size.width == 456)
    }

    @Test("no answer is ever the scratch width unless the ink really is that wide")
    func neverAnswersWithTheScratchWidth() {
        let proposals: [Double?] = [nil, .infinity, 0, -20, 1, 456, 592]
        for proposed in proposals {
            for widestLine in [0.0, -4.0, 12.0] {
                for usedHeight in [0.0, 35.0] {
                    let size = TranscriptTextMeasure.size(
                        widestLine: widestLine, usedHeight: usedHeight,
                        proposed: proposed, lineHeight: 16, hasGlyphs: true
                    )
                    let place = "widest line \(widestLine), height \(usedHeight), "
                        + "proposal \(String(describing: proposed))"
                    #expect(size.width > 0, "\(place) reported a width of \(size.width)")
                    #expect(size.height > 0, "\(place) reported a height of \(size.height)")
                    #expect(
                        size.width < TranscriptTextMeasure.idealWidth,
                        "\(place) reported a width of \(size.width)"
                    )
                }
            }
        }
    }
}
