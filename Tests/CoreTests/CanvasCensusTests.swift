import Foundation
import Testing
@testable import Core

@Suite("CanvasCensus")
struct CanvasCensusTests {
    @Test("a canvas pane reports its path")
    func paneReportsPath() {
        let entry = PaneCensusEntry(kind: .canvas, name: "Canvas", isShowing: true, canvasPath: "docs/a.html")

        #expect(entry.json["kind"] == .string("canvas"))
        #expect(entry.json["path"] == .string("docs/a.html"))
    }

    @Test("a pane that is not a canvas carries no path")
    func otherPaneHasNoPath() {
        let entry = PaneCensusEntry(kind: .review, name: "All changes", isShowing: false)

        #expect(entry.json["path"] == nil)
    }

    @Test("a canvas tab describes its path")
    func tabDescribesPath() {
        let detail = WorkspaceTabDetail.canvas(WorkspaceTabCanvas(path: "a.md"))

        #expect(detail.kind == .canvas)
        #expect(detail.json["path"] == .string("a.md"))
    }

    @Test("a canvas tab report keys its detail under canvas")
    func tabReportKeysDetail() {
        let report = WorkspaceTabReport(
            number: 2, title: "Canvas", isActive: true,
            detail: .canvas(WorkspaceTabCanvas(path: "docs/plan.html"))
        )

        #expect(report.json["kind"] == .string("canvas"))
        #expect(report.json["canvas"]?["path"] == .string("docs/plan.html"))
    }

    @Test("a canvas cannot be duplicated")
    func cannotDuplicate() {
        #expect(PaneSplit.duplicating(.tool("x"), tabKind: .canvas) == .nothing)
    }

    @Test("a canvas cannot be renamed")
    func cannotRename() {
        #expect(!TabRenaming.canRename(.tool("x"), tabKind: .canvas))
    }

    @Test("a census kind maps from the canvas tab kind")
    func censusKindMaps() {
        #expect(PaneCensusKind(.canvas) == .canvas)
    }
}
