import Testing
@testable import Core

@Suite("What the owner is told about a stroke")
struct CanvasStrokeNoticeTests {
    @Test func aSimplifiedStrokeIsSaidToHaveBeenSimplified() {
        let notice = CanvasStrokeNotice.reduced()
        #expect(notice.tone == .information)
        #expect(notice.title.contains("simplified"))
        #expect(!notice.lines.isEmpty)
    }

    @Test func aRefusedStrokeNamesTheReason() {
        let notice = CanvasStrokeNotice.refused("A canvas takes at most 200000 stroke points in all.")
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
        #expect(CanvasStrokeNotice.refused(reason).lines.first?.contains("\(CanvasStrokeBuilder.maximumDocumentPoints)") == true)
    }
}
