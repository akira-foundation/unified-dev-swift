import Foundation
import Testing
@testable import Core

@Suite("Canvas document codec", .tags(.persistence))
struct CanvasDocumentCodecTests {
    private func run(_ text: String) -> CanvasTextRun {
        CanvasTextRun(text: text, fontName: "Helvetica", size: 14, weight: 0.4, colour: "#112233")
    }

    private func sample() -> CanvasDocument {
        let frame = CanvasFrame(id: CanvasFrameID("f1"), name: "Home", rect: CanvasRect(x: 0, y: 0, width: 390, height: 844))
        let rect = CanvasRect(x: 10, y: 20, width: 100, height: 50)
        let shadow = CanvasShadow(offsetX: 1, offsetY: 2, radius: 3, colour: "#00000080")
        let styled = CanvasStyle(fill: "#FF0000", stroke: "#000000", strokeWidth: 2, cornerRadius: 4, opacity: 0.5, rotation: 15, shadow: shadow)
        let text = CanvasText(runs: [run("Hello")], alignment: .centre)
        let elements: [CanvasElement] = [
            CanvasElement(id: CanvasElementID("e1"), frameID: frame.id, revision: 3, rect: rect, style: styled, kind: .text(text)),
            CanvasElement(id: CanvasElementID("e2"), rect: rect, kind: .image(path: "assets/a.png")),
            CanvasElement(id: CanvasElementID("e3"), rect: rect, kind: .shape(CanvasShape(kind: .arrow))),
            CanvasElement(id: CanvasElementID("e4"), rect: rect, kind: .note(text)),
            CanvasElement(
                id: CanvasElementID("e5"),
                rect: rect,
                kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 1, y: 1), CanvasPoint(x: 2, y: 3)], width: 2, colour: "#0000FF"))
            )
        ]
        let comment = CanvasComment(
            id: CanvasCommentID("c1"),
            anchor: CanvasPoint(x: 5, y: 6),
            frameID: frame.id,
            elementID: CanvasElementID("e1"),
            text: "Tighten this",
            state: .resolved,
            response: "Done",
            deliveryID: DeliveryID("d1"),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        return CanvasDocument(frames: [frame], elements: elements, comments: [comment])
    }

    @Test("a document with one element of each kind survives encode and decode")
    func documentRoundTrips() throws {
        let document = sample()
        let decoded = CanvasDocumentCodec.decode(try CanvasDocumentCodec.encode(document))
        #expect(decoded == .document(document))
    }

    @Test("encoding is byte stable, sorted and multi line")
    func encodingIsStable() throws {
        let document = sample()
        let first = try CanvasDocumentCodec.encode(document)
        let second = try CanvasDocumentCodec.encode(document)
        let text = String(decoding: first, as: UTF8.self)
        let comments = try #require(text.range(of: "\"comments\""))
        let elements = try #require(text.range(of: "\"elements\""))
        let frames = try #require(text.range(of: "\"frames\""))
        #expect(first == second)
        #expect(text.split(separator: "\n").count > 10)
        #expect(comments.lowerBound < elements.lowerBound)
        #expect(elements.lowerBound < frames.lowerBound)
        #expect(!text.contains("\\/"))
    }

    @Test("bytes that are not a document are reported as corrupt")
    func corruptIsReported() {
        let result = CanvasDocumentCodec.decode(Data("not json".utf8))
        guard case .corrupt = result else {
            Issue.record("expected corrupt, got \(result)")
            return
        }
    }

    @Test("a newer version is refused with its number")
    func newerVersionIsRefused() {
        let data = Data(#"{"version": 2, "frames": [], "elements": [], "comments": []}"#.utf8)
        #expect(CanvasDocumentCodec.decode(data) == .newerVersion(2))
    }
}
