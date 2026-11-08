import Testing
@testable import Core

@Suite("What the owner is told about a stroke")
struct CanvasStrokeNoticeTests {
    @Test func aStrokeThatWasNeitherRefusedNorCoarsenedSaysNothing() {
        #expect(CanvasStrokeNotice.after(refusal: nil, reduced: false) == nil)
    }

    @Test func aCoarsenedStrokeIsSaidToHaveLostDetailAndClaimsNothingMore() throws {
        let notice = try #require(CanvasStrokeNotice.after(refusal: nil, reduced: true))
        #expect(notice.tone == .information)
        let said = ([notice.title] + notice.lines).joined(separator: " ")
        #expect(said.contains("detail"))
        #expect(!said.contains("Corners") && !said.contains("spikes") && !said.contains("keeps") && !said.contains("small"))
    }

    @Test func aRefusalNamesTheReasonAndWinsOverACoarsening() throws {
        let notice = try #require(CanvasStrokeNotice.after(refusal: "A canvas takes at most 200000 stroke points in all.", reduced: true))
        #expect(notice.tone == .warning)
        #expect(notice.lines == ["A canvas takes at most 200000 stroke points in all."])
    }

    @Test func aStrokeTheSessionRefusesAtTheDocumentLimitProducesTheReason() {
        let chunk = (0..<CanvasStrokeBuilder.maximumPoints).map { CanvasPoint(x: Double($0 % 90), y: Double($0 % 40)) }
        let strokes = (0...(CanvasStrokeBuilder.maximumDocumentPoints / CanvasStrokeBuilder.maximumPoints)).map {
            CanvasElement(
                id: CanvasElementID("s\($0)"), rect: CanvasRect(x: 0, y: 0, width: 100, height: 50),
                kind: .stroke(CanvasStroke(points: chunk, width: 2, colour: "#000000"))
            )
        }
        var session = CanvasDocumentSession(document: CanvasDocument())
        guard case .invalid(let reason) = session.apply(strokes.map { .addElement($0) }, by: .owner) else {
            Issue.record("expected a refusal")
            return
        }
        let notice = CanvasStrokeNotice.after(refusal: reason, reduced: false)
        #expect(notice?.lines.first?.contains("\(CanvasStrokeBuilder.maximumDocumentPoints)") == true)
    }
}
