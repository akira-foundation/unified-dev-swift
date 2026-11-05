import Foundation
import Testing
@testable import Core

@Suite("What an export says it left out")
struct CanvasExportReportTests {
    private let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 0, y: 0, width: 100, height: 100))

    private func shape(_ id: String, in frameID: CanvasFrameID?, _ rect: CanvasRect) -> CanvasElement {
        CanvasElement(id: CanvasElementID(id), frameID: frameID, rect: rect, kind: .shape(CanvasShape(kind: .rectangle)))
    }

    @Test func theExportSaysHowManyElementsWereLeftOutside() {
        let report = CanvasExportReport(written: ["01-a.png"], looseElements: 2)
        #expect(report.hasProblems)
        #expect(report.lines.contains { $0.contains("2 elements") && $0.contains("outside every frame") })
        #expect(!CanvasExportReport(written: ["01-a.png"]).lines.contains { $0.contains("outside every frame") })
    }

    @Test func anElementThatSitsOutsideItsOwnFrameIsLeftOut() {
        let inside = shape("in", in: frame.id, CanvasRect(x: 10, y: 10, width: 20, height: 20))
        let straddling = shape("edge", in: frame.id, CanvasRect(x: 90, y: 90, width: 50, height: 50))
        let away = shape("away", in: frame.id, CanvasRect(x: 400, y: 10, width: 20, height: 20))
        let loose = shape("loose", in: nil, CanvasRect(x: 10, y: 10, width: 20, height: 20))
        let document = CanvasDocument(frames: [frame], elements: [inside, straddling, away, loose])
        #expect(document.looseElementCount == 2)
    }

    @Test func aFrameShrunkAwayFromItsElementsLeavesThemOut() {
        let element = shape("e", in: frame.id, CanvasRect(x: 60, y: 60, width: 20, height: 20))
        var document = CanvasDocument(frames: [frame], elements: [element])
        #expect(document.looseElementCount == 0)
        document.frames[0].rect.size = CanvasSize(width: 50, height: 50)
        #expect(document.looseElementCount == 1)
    }
}
