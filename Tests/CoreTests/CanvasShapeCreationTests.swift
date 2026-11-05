import Foundation
import Testing
@testable import Core

@Suite("Drawing shapes and notes")
struct CanvasShapeCreationTests {
    private let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 1_000, y: 200, width: 1_080, height: 1_080))
    private var document: CanvasDocument { CanvasDocument(frames: [frame]) }

    @Test func aDraggedRectangleIsNormalisedAndFrameRelative() {
        let element = CanvasEditing.newShape(.rectangle, from: CanvasPoint(x: 1_300, y: 500), to: CanvasPoint(x: 1_100, y: 400), in: document)
        #expect(element.frameID == frame.id)
        #expect(element.rect == CanvasRect(x: 100, y: 200, width: 200, height: 100))
        #expect(element.style.stroke != nil && element.style.fill == nil && element.style.strokeWidth > 0)
    }

    @Test func aClickMakesADefaultSizedShapeCentredOnIt() {
        let click = CanvasPoint(x: 1_500, y: 600)
        let element = CanvasEditing.newShape(.ellipse, from: click, to: click, in: document)
        #expect(element.rect.size == CanvasSize(width: CanvasEditing.defaultShapeWidth, height: CanvasEditing.defaultShapeHeight))
        #expect(element.rect.origin.x + element.rect.size.width / 2 == 500)
        #expect(element.rect.origin.y + element.rect.size.height / 2 == 400)
    }

    @Test func aDraggedLineRunsFromTheStartToTheEndByRotation() {
        let element = CanvasEditing.newShape(.line, from: CanvasPoint(x: 1_100, y: 300), to: CanvasPoint(x: 1_100, y: 500), in: document)
        #expect(element.rect.size.width == 200)
        #expect(element.style.rotation == 90)
        #expect(element.rect.origin.x + element.rect.size.width / 2 == 100)
        #expect(element.rect.origin.y + element.rect.size.height / 2 == 200)
    }

    @Test func aShapeOutsideEveryFrameIsLooseAtItsAbsolutePosition() {
        let element = CanvasEditing.newShape(.rectangle, from: CanvasPoint(x: 10, y: 20), to: CanvasPoint(x: 110, y: 90), in: document)
        #expect(element.frameID == nil)
        #expect(element.rect == CanvasRect(x: 10, y: 20, width: 100, height: 70))
    }

    @Test func aNoteIsAnEmptyTextOnAFilledCard() {
        let element = CanvasEditing.newNote(at: CanvasPoint(x: 1_100, y: 300), in: document)
        #expect(element.isNote && element.frameID == frame.id)
        #expect(element.text?.runs.first?.text == "")
        #expect(element.style.fill != nil)
        #expect(element.rect.origin == CanvasPoint(x: 100, y: 100))
    }

    @Test func aNoteNearTheEdgeStaysInsideItsFrame() {
        let element = CanvasEditing.newNote(at: CanvasPoint(x: 2_000, y: 1_250), in: document)
        #expect(element.rect.origin.x + element.rect.size.width <= frame.rect.size.width)
        #expect(element.rect.origin.y + element.rect.size.height <= frame.rect.size.height)
    }

    @Test func theAgentAndThePenGetTheSameLimitOnStrokePoints() {
        func stroke(_ count: Int) -> CanvasElement {
            CanvasElement(
                rect: CanvasRect(x: 0, y: 0, width: 10, height: 10),
                kind: .stroke(CanvasStroke(points: Array(repeating: CanvasPoint(x: 1, y: 1), count: count), width: 2, colour: "#000000"))
            )
        }
        var session = CanvasDocumentSession(document: CanvasDocument())
        let within = session.apply([.addElement(stroke(CanvasStrokeBuilder.maximumPoints))], by: .agent)
        let beyond = session.apply([.addElement(stroke(CanvasStrokeBuilder.maximumPoints + 1))], by: .agent)
        guard case .applied = within, case .invalid(let reason) = beyond else {
            Issue.record("expected applied then invalid, got \(within) and \(beyond)")
            return
        }
        #expect(reason.contains("\(CanvasStrokeBuilder.maximumPoints)"))
    }

    @Test func resizingAStrokeScalesItsPointsInTheSameOperation() throws {
        let stroke = CanvasElement(
            id: CanvasElementID("s"), rect: CanvasRect(x: 0, y: 0, width: 104, height: 54),
            kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 2, y: 2), CanvasPoint(x: 102, y: 52)], width: 4, colour: "#000000"))
        )
        let document = CanvasDocument(elements: [stroke])
        let operations = CanvasMove.operations(placing: stroke.id, at: CanvasRect(x: 0, y: 0, width: 204, height: 104), in: document)
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(operations, by: .owner)
        let resized = try #require(session.document.elements.first)
        guard case .stroke(let result) = resized.kind else { Issue.record("not a stroke"); return }
        #expect(resized.rect.size == CanvasSize(width: 204, height: 104))
        #expect(result.points == [CanvasPoint(x: 2, y: 2), CanvasPoint(x: 202, y: 102)])
    }

    @Test func movingAStrokeLeavesItsPointsAlone() throws {
        let stroke = CanvasElement(
            id: CanvasElementID("s"), rect: CanvasRect(x: 0, y: 0, width: 104, height: 54),
            kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 2, y: 2), CanvasPoint(x: 102, y: 52)], width: 4, colour: "#000000"))
        )
        let document = CanvasDocument(elements: [stroke])
        let operations = CanvasMove.operations(placing: stroke.id, at: CanvasRect(x: 50, y: 70, width: 104, height: 54), in: document)
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(operations, by: .owner)
        #expect(session.document.elements.first?.kind == stroke.kind)
        #expect(session.document.elements.first?.rect.origin == CanvasPoint(x: 50, y: 70))
    }

    @Test func anAgentCanAddAShapeANoteAndALargeStrokeInOneCall() throws {
        let big = CanvasStroke(
            points: (0..<CanvasStrokeBuilder.maximumPoints).map { CanvasPoint(x: Double($0 % 100), y: Double($0 % 37)) },
            width: 3, colour: "#112233"
        )
        let added: [CanvasElement] = [
            CanvasEditing.newShape(.arrow, from: CanvasPoint(x: 1_010, y: 210), to: CanvasPoint(x: 1_200, y: 210), in: document),
            CanvasEditing.newNote(at: CanvasPoint(x: 1_100, y: 300), in: document),
            CanvasElement(frameID: frame.id, rect: CanvasRect(x: 0, y: 0, width: 100, height: 40), kind: .stroke(big)),
        ]
        let wire = try added.map { try JSONValue.parse(JSONEncoder().encode(CanvasOperation.addElement($0))).unwrapped() }
        let decoded = try wire.map { try JSONDecoder().decode(CanvasOperation.self, from: JSONEncoder().encode($0)) }
        var session = CanvasDocumentSession(document: document)
        let outcome = session.apply(decoded, by: .agent)
        guard case .applied(let result) = outcome else { Issue.record("not applied: \(outcome)"); return }
        #expect(result.elements.map(\.kind) == added.map(\.kind))
    }

    @Test func theEditToolSaysHowStrokePointsAreStoredAndHowManyAreAllowed() {
        let description = CanvasEditTool { _, _, _ in .refused("unused") }.tool.description
        #expect(description.contains("relative to the origin of the element's rect"))
        #expect(description.contains("at most \(CanvasStrokeBuilder.maximumPoints) points"))
        #expect(description.contains("\(CanvasEditToolName.maxOperations) operations"))
    }
}

private extension Optional {
    func unwrapped() throws -> Wrapped {
        guard let self else { throw UnwrapFailure() }
        return self
    }
}

private struct UnwrapFailure: Error {}
