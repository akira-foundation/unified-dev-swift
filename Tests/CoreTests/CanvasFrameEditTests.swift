import Foundation
import Testing
@testable import Core

@Suite("Changing a frame from its panel")
struct CanvasFrameEditTests {
    private static let frame = CanvasFrame(id: CanvasFrameID("f"), name: "One", rect: CanvasRect(x: 10, y: 20, width: 500, height: 600), fill: "#FFFFFF")
    private let document = CanvasDocument(frames: [frame])

    private func applied(_ operations: [CanvasOperation]) -> CanvasFrame? {
        var session = CanvasDocumentSession(document: document)
        guard case .applied(let result) = session.apply(operations, by: .owner) else { return nil }
        return result.frames.first
    }

    @Test func aFrameIsRenamed() {
        let operations = CanvasFrameEdit.operations(renaming: Self.frame.id, to: "  Cover ", in: document)
        #expect(applied(operations)?.name == "Cover")
    }

    @Test func aBlankNameOrTheSameNameChangesNothing() {
        #expect(CanvasFrameEdit.operations(renaming: Self.frame.id, to: "   ", in: document).isEmpty)
        #expect(CanvasFrameEdit.operations(renaming: Self.frame.id, to: "One", in: document).isEmpty)
    }

    @Test func aFrameIsPainted() {
        let operations = CanvasFrameEdit.operations(filling: Self.frame.id, with: "#112233", in: document)
        #expect(applied(operations)?.fill == "#112233")
        #expect(CanvasFrameEdit.operations(filling: Self.frame.id, with: "#FFFFFF", in: document).isEmpty)
    }

    @Test func eachCoordinateMovesItOnItsOwn() {
        let across = CanvasFrameEdit.operations(placing: Self.frame.id, x: -40, in: document)
        #expect(applied(across)?.rect == CanvasRect(x: -40, y: 20, width: 500, height: 600))
        let down = CanvasFrameEdit.operations(placing: Self.frame.id, y: 90, in: document)
        #expect(applied(down)?.rect == CanvasRect(x: 10, y: 90, width: 500, height: 600))
        #expect(CanvasFrameEdit.operations(placing: Self.frame.id, x: 10, in: document).isEmpty)
    }

    @Test func aPositionThatIsNotANumberChangesNothing() {
        #expect(CanvasFrameEdit.operations(placing: Self.frame.id, x: .infinity, in: document).isEmpty)
        #expect(CanvasFrameEdit.operations(placing: Self.frame.id, y: .nan, in: document).isEmpty)
    }

    @Test func aFrameThatIsGoneChangesNothing() {
        let gone = CanvasFrameID("gone")
        #expect(CanvasFrameEdit.operations(renaming: gone, to: "x", in: document).isEmpty)
        #expect(CanvasFrameEdit.operations(filling: gone, with: "#000000", in: document).isEmpty)
        #expect(CanvasFrameEdit.operations(placing: gone, x: 1, in: document).isEmpty)
    }

    @Test func aNewFreeFrameCanBeGivenAnySizeOnceItIsSelected() throws {
        let frame = CanvasFramePreset.free.newFrame(after: [])
        var session = CanvasDocumentSession(document: CanvasDocument())
        _ = session.apply([.addFrame(frame)], by: .owner)
        let press = CanvasSelection().pressed(label: frame.id, element: nil, at: CanvasPoint(x: 0, y: 0), extending: false, in: session.document)
        let selected = try #require(press.selection.frame)
        let operations = CanvasFrameSize.operations(resizing: selected, to: CanvasSize(width: 640, height: 480), in: session.document)
        _ = session.apply(operations, by: .owner)
        #expect(session.document.frames.first?.rect.size == CanvasSize(width: 640, height: 480))
    }
}
