import Foundation
@testable import Core

struct CanvasSessionFixture {
    let frameID = CanvasFrameID("f1")
    let titleID = CanvasElementID("title")
    let boxID = CanvasElementID("box")

    func session() -> CanvasDocumentSession {
        CanvasDocumentSession(document: CanvasDocument(
            frames: [CanvasFrame(id: frameID, name: "One", rect: CanvasRect(x: 0, y: 0, width: 100, height: 100), revision: 3)],
            elements: [
                CanvasElement(
                    id: titleID, frameID: frameID, revision: 2,
                    rect: CanvasRect(x: 0, y: 0, width: 50, height: 20),
                    kind: .text(CanvasText(runs: [
                        CanvasTextRun(text: "Hi", fontName: "Helvetica", size: 12, weight: 0, colour: "#000000"),
                    ]))
                ),
                CanvasElement(
                    id: boxID, frameID: frameID, revision: 0,
                    rect: CanvasRect(x: 5, y: 5, width: 10, height: 10),
                    kind: .shape(CanvasShape(kind: .rectangle))
                ),
            ]
        ))
    }

    func move(_ id: CanvasElementID, revision: Int?) -> CanvasOperation {
        .updateElement(id, expectedRevision: revision, CanvasElementPatch(rect: CanvasRect(x: 9, y: 9, width: 50, height: 20)))
    }
}
