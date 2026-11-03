import Testing
@testable import Core

@Suite("CanvasFramePreset")
struct CanvasFramePresetTests {
    @Test func presetsMatchTheDesign() {
        #expect(CanvasFramePreset.square.size == CanvasSize(width: 1080, height: 1080))
        #expect(CanvasFramePreset.portrait.size == CanvasSize(width: 1080, height: 1350))
        #expect(CanvasFramePreset.free.size == nil)
        #expect(CanvasFramePreset.allCases.count == 3)
    }

    @Test func aNewFrameGoesToTheRightOfTheRightmost() {
        let frames = [
            CanvasFrame(name: "B", rect: CanvasRect(x: 1200, y: 40, width: 1080, height: 1080)),
            CanvasFrame(name: "A", rect: CanvasRect(x: 0, y: 0, width: 1080, height: 1080)),
        ]
        let frame = CanvasFramePreset.portrait.newFrame(after: frames)
        #expect(frame.rect.origin == CanvasPoint(x: 2280 + CanvasFramePreset.gap, y: 40))
        #expect(frame.rect.size == CanvasSize(width: 1080, height: 1350))
        #expect(frame.name == "Slide 3")
    }

    @Test func theFirstFrameStartsAtTheOrigin() {
        let frame = CanvasFramePreset.free.newFrame(after: [])
        #expect(frame.rect.origin == CanvasPoint(x: 0, y: 0))
        #expect(frame.rect.size == CanvasFramePreset.freeDefaultSize)
        #expect(frame.name == "Slide 1")
    }
}

@Suite("CanvasStacking")
struct CanvasStackingTests {
    private func document() -> CanvasDocument {
        CanvasDocument(elements: ["a", "b", "c"].map {
            CanvasElement(id: CanvasElementID($0), rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), kind: .shape(CanvasShape(kind: .rectangle)))
        })
    }

    private func order(after direction: CanvasStackingDirection, of id: String) -> [String] {
        let document = document()
        var session = CanvasDocumentSession(document: document)
        let operations = CanvasStacking.operations(moving: CanvasElementID(id), direction, in: document)
        _ = session.apply(operations, by: .owner)
        return session.document.elements.map(\.id.rawValue)
    }

    @Test func stackingMovesOneStepOrToTheEnds() {
        #expect(order(after: .forward, of: "a") == ["b", "a", "c"])
        #expect(order(after: .backward, of: "c") == ["a", "c", "b"])
        #expect(order(after: .toFront, of: "a") == ["b", "c", "a"])
        #expect(order(after: .toBack, of: "c") == ["c", "a", "b"])
    }

    @Test func stackingPastTheEndsDoesNothing() {
        let document = document()
        #expect(CanvasStacking.operations(moving: CanvasElementID("c"), .forward, in: document).isEmpty)
        #expect(CanvasStacking.operations(moving: CanvasElementID("a"), .toBack, in: document).isEmpty)
    }
}
