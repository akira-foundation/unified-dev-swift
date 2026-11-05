import Foundation
import Testing
@testable import Core

@Suite("An agent's colours are checked")
struct CanvasDocumentSessionColourTests {
    private static let frame = CanvasFrame(id: CanvasFrameID("f"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 100, height: 100))

    private static func shape(fill: String? = nil, stroke: String? = nil, shadow: String? = nil) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID("e"), frameID: frame.id, rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            style: CanvasStyle(fill: fill, stroke: stroke, shadow: shadow.map { CanvasShadow(offsetX: 0, offsetY: 0, radius: 1, colour: $0) }),
            kind: .shape(CanvasShape(kind: .rectangle))
        )
    }

    private func refusal(_ operation: CanvasOperation, by author: CanvasAuthor = .agent, in document: CanvasDocument) -> String? {
        var session = CanvasDocumentSession(document: document)
        guard case .invalid(let reason) = session.apply([operation], by: author) else { return nil }
        return reason
    }

    private var empty: CanvasDocument { CanvasDocument(frames: [Self.frame]) }

    @Test(arguments: [
        shape(fill: "red"), shape(stroke: "blue"), shape(shadow: "#12"),
        CanvasElement(
            id: CanvasElementID("t"), frameID: frame.id, rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            kind: .text(CanvasText(runs: [CanvasTextRun(text: "a", fontName: "Helvetica", size: 12, weight: 0, colour: "green")]))
        ),
        CanvasElement(
            id: CanvasElementID("n"), frameID: frame.id, rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            kind: .note(CanvasText(runs: [CanvasTextRun(text: "a", fontName: "Helvetica", size: 12, weight: 0, colour: "#GGGGGG")]))
        ),
        CanvasElement(
            id: CanvasElementID("p"), frameID: frame.id, rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
            kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 1, y: 1)], width: 1, colour: "pink"))
        ),
    ])
    func aNewElementWithAColourNobodyCanDrawIsRefused(_ element: CanvasElement) throws {
        let reason = try #require(refusal(.addElement(element), in: empty))
        #expect(reason.contains("#RRGGBB"))
        #expect(reason.contains(element.id.rawValue))
    }

    @Test func aGoodColourGoesThrough() {
        #expect(refusal(.addElement(Self.shape(fill: "#FF0000", stroke: "#00FF0080")), in: empty) == nil)
    }

    @Test func aPatchThatBringsABadColourIsRefused() throws {
        let document = CanvasDocument(frames: [Self.frame], elements: [Self.shape(fill: "#FF0000")])
        let patch = CanvasElementPatch(style: CanvasStylePatch(fill: "red"))
        let reason = try #require(refusal(.updateElement(CanvasElementID("e"), expectedRevision: 0, patch), in: document))
        #expect(reason.contains("\"red\""))
    }

    @Test func aFrameWithABadFillIsRefusedOnAddAndOnUpdate() throws {
        var added = Self.frame
        added.id = CanvasFrameID("g")
        added.fill = "red"
        let onAdd = try #require(refusal(.addFrame(added), in: empty))
        #expect(onAdd.contains("\"red\""))
        let onUpdate = try #require(refusal(.updateFrame(Self.frame.id, expectedRevision: 0, CanvasFramePatch(fill: "red")), in: empty))
        #expect(onUpdate.contains("\"red\""))
    }

    @Test func aFileAlreadyOnDiskWithABadColourStillOpensAndCanBeMoved() throws {
        let document = CanvasDocument(frames: [Self.frame], elements: [Self.shape(fill: "red")])
        let opened = CanvasDocumentCodec.decode(try CanvasDocumentCodec.encode(document))
        #expect(opened == .document(document))
        let patch = CanvasElementPatch(rect: CanvasRect(x: 5, y: 5, width: 10, height: 10))
        #expect(refusal(.updateElement(CanvasElementID("e"), expectedRevision: 0, patch), in: document) == nil)
    }

    @Test func theOwnerIsNotChecked() {
        #expect(refusal(.addElement(Self.shape(fill: "red")), by: .owner, in: empty) == nil)
    }
}
