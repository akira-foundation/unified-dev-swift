import Foundation
import Testing
@testable import Core

@Suite("An agent's answer counts a stroke's points", .scratchDirectory)
struct CanvasAnswerStrokePointsTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private static let scribble = CanvasElement(
        id: CanvasElementID("pen"), revision: 3, rect: CanvasRect(x: 0, y: 0, width: 50, height: 50),
        kind: .stroke(CanvasStroke(points: (0..<2_048).map { CanvasPoint(x: Double($0), y: 1) }, width: 4, colour: "#112233"))
    )

    private func stroke(in value: JSONValue?) -> [String: JSONValue]? {
        guard case .object(let element)? = value, case .object(let kind)? = element["kind"],
              case .object(let wrapper)? = kind["stroke"], case .object(let stroke)? = wrapper["_0"] else { return nil }
        return stroke
    }

    private func answer(_ result: BridgeToolResult) throws -> [String: JSONValue] {
        guard case .object(let fields)? = canvasAnswerJSON(result.text) else { throw CocoaError(.coderReadCorrupt) }
        return fields
    }

    @Test func aReadAnswerGivesACountInPlaceOfThePoints() async throws {
        let store = try makeTestStore("canvas-read-points")
        let tool = CanvasReadTool { _, _ in
            .read(CanvasReadAnswer(document: CanvasDocument(elements: [Self.scribble]), measuredTextSize: [:]))
        }
        let request = MCPRequest(id: .integer(1), method: CanvasReadToolName.read, params: .object(["path": .string("c.udcanvas")]))
        let result = await tool.call(request, as: identity, store: store)
        let fields = try answer(result)
        guard case .object(let document)? = fields["document"], case .array(let elements)? = document["elements"] else {
            Issue.record("no elements in \(result.text)")
            return
        }
        let stroke = try #require(stroke(in: elements.first))
        #expect(stroke["points"] == nil)
        #expect(stroke["pointCount"] == .integer(2_048))
        #expect(stroke["colour"] == .string("#112233"))
        #expect(result.text.utf8.count < 3_000)
    }

    @Test func aConflictAnswerGivesACountInPlaceOfThePoints() async throws {
        let store = try makeTestStore("canvas-edit-points")
        let tool = CanvasEditTool { _, _, _ in
            .conflict([CanvasConflict(target: "pen", revision: 3, current: .element(Self.scribble))])
        }
        let operation = try JSONValue.parse(JSONEncoder().encode(CanvasOperation.deleteElement(Self.scribble.id, expectedRevision: 1)))
        let request = MCPRequest(
            id: .integer(1), method: CanvasEditToolName.edit,
            params: .object(["path": .string("c.udcanvas"), "operations": .array([try #require(operation)])])
        )
        let result = await tool.call(request, as: identity, store: store)
        let fields = try answer(result)
        guard case .array(let conflicts)? = fields["conflicts"], case .object(let first)? = conflicts.first else {
            Issue.record("no conflict in \(result.text)")
            return
        }
        let stroke = try #require(stroke(in: first["element"]))
        #expect(stroke["points"] == nil)
        #expect(stroke["pointCount"] == .integer(2_048))
    }

    @Test func aPatchWithNoKindKeepsThePointsItWasNotShown() {
        var session = CanvasDocumentSession(document: CanvasDocument(elements: [Self.scribble]))
        let patch = CanvasElementPatch(style: CanvasStylePatch(opacity: 0.5))
        let outcome = session.apply([.updateElement(Self.scribble.id, expectedRevision: 3, patch)], by: .agent)
        guard case .applied(let document) = outcome else {
            Issue.record("refused: \(outcome)")
            return
        }
        #expect(document.elements.first?.kind == Self.scribble.kind)
    }

    @Test func theToolsSayThePointsAreCounted() {
        #expect(CanvasReadTool { _, _ in .refused("x") }.tool.description.contains("pointCount"))
        #expect(CanvasEditTool { _, _, _ in .refused("x") }.tool.description.contains("pointCount"))
    }
}
