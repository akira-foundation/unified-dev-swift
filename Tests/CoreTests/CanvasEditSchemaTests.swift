import Foundation
import Testing
@testable import Core

@Suite("The canvas_edit schema")
struct CanvasEditSchemaTests {
    @Test("a frame and an element built only from the schema's required keys decode")
    func schemaRequiredKeysAreEnough() throws {
        let rect = JSONValue.object([
            "origin": .object(["x": .integer(1), "y": .integer(2)]),
            "size": .object(["width": .integer(30), "height": .integer(40)]),
        ])
        let style = JSONValue.object([
            "strokeWidth": .integer(0), "cornerRadius": .integer(0), "opacity": .integer(1), "rotation": .integer(0),
        ])
        let frame = JSONValue.object([
            "op": .string("addFrame"),
            "frame": .object([
                "id": .string("f2"), "name": .string("Two"), "rect": rect, "fill": .string("#FFFFFF"), "revision": .integer(0),
            ]),
        ])
        let element = JSONValue.object([
            "op": .string("addElement"),
            "element": .object([
                "id": .string("n"), "revision": .integer(0), "rect": rect, "style": style,
                "kind": .object(["shape": .object(["_0": .object(["kind": .string("ellipse")])])]),
            ]),
        ])
        let text = JSONValue.object([
            "op": .string("addElement"),
            "element": .object([
                "id": .string("t"), "revision": .integer(0), "rect": rect, "style": style,
                "kind": .object(["text": .object(["_0": .object([
                    "alignment": .string("leading"),
                    "runs": .array([.object([
                        "text": .string("Hi"), "fontName": .string("Helvetica"), "size": .integer(12),
                        "weight": .integer(400), "colour": .string("#000000"),
                    ])]),
                ])])]),
            ]),
        ])

        for operation in [frame, element, text] {
            let data = try JSONEncoder().encode(operation)
            #expect(throws: Never.self) { try JSONDecoder().decode(CanvasOperation.self, from: data) }
        }
        let item = try operationSchema()
        #expect(try required(["properties", "frame"], in: item).isSuperset(of: ["id", "name", "rect", "fill", "revision"]))
        #expect(try required(["properties", "element"], in: item).isSuperset(of: ["id", "revision", "rect", "style", "kind"]))
        let textKeys = try required(["properties", "element", "properties", "kind", "properties", "text", "properties", "_0"], in: item)
        #expect(textKeys.isSuperset(of: ["runs", "alignment"]))
    }

    private func operationSchema() throws -> JSONValue {
        let listing = CanvasEditTool { _, _, _ in .refused("x") }.tool.listing
        guard case .object(let fields) = listing, case .object(let schema)? = fields["inputSchema"],
              case .object(let properties)? = schema["properties"], case .object(let operations)? = properties["operations"],
              let items = operations["items"] else {
            throw SchemaMissing()
        }
        return items
    }

    private struct SchemaMissing: Error {}

    private func required(_ path: [String], in schema: JSONValue) throws -> Set<String> {
        var node = schema
        for key in path {
            guard case .object(let fields) = node, let next = fields[key] else { throw SchemaMissing() }
            node = next
        }
        guard case .object(let fields) = node, case .array(let names)? = fields["required"] else { throw SchemaMissing() }
        return Set(names.compactMap(\.stringValue))
    }

    @Test("the patch accepts either kind of patch, not exactly one")
    func patchSchemaIsAnyOf() throws {
        guard case .object(let items) = try operationSchema(), case .object(let itemProperties)? = items["properties"],
              case .object(let patch)? = itemProperties["patch"] else {
            Issue.record("no patch schema")
            return
        }
        #expect(patch["type"] == .string("object"))
        #expect(patch["anyOf"] != nil)
        #expect(patch["oneOf"] == nil)
    }

    private func node(_ path: [String], in schema: JSONValue) throws -> JSONValue {
        var node = schema
        for key in path {
            guard case .object(let fields) = node, let next = fields[key] else { throw SchemaMissing() }
            node = next
        }
        return node
    }

    private func sample(of name: CanvasOperation.Name) -> CanvasOperation {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 0, y: 0, width: 1, height: 1))
        let element = CanvasElement(id: CanvasElementID("e"), rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), kind: .image(path: "a.png"))
        return switch name {
        case .addFrame: .addFrame(frame)
        case .updateFrame: .updateFrame(frame.id, expectedRevision: 1, CanvasFramePatch(name: "G"))
        case .deleteFrame: .deleteFrame(frame.id, expectedRevision: 1)
        case .addElement: .addElement(element)
        case .updateElement: .updateElement(element.id, expectedRevision: 1, CanvasElementPatch(clearFrame: true))
        case .deleteElement: .deleteElement(element.id, expectedRevision: 1)
        case .reorder: .reorder(element.id, toIndex: 0)
        }
    }

    @Test("the op enum in the schema is exactly the operations the type has")
    func opEnumIsDerivedFromTheType() throws {
        guard case .array(let options) = try node(["properties", "op", "enum"], in: try operationSchema()) else { throw SchemaMissing() }
        #expect(options.compactMap(\.stringValue) == CanvasOperation.Name.allCases.map(\.rawValue))
    }

    @Test("every name decodes to the operation of that name", arguments: CanvasOperation.Name.allCases)
    func everyNameRoundTrips(name: CanvasOperation.Name) throws {
        let operation = sample(of: name)
        let decoded = try JSONDecoder().decode(CanvasOperation.self, from: JSONEncoder().encode(operation))
        #expect(operation.name == name)
        #expect(decoded == operation)
    }

    @Test("an operation the type does not have is refused")
    func anUnknownOperationIsRefused() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CanvasOperation.self, from: Data(#"{"op":"explode","id":"e"}"#.utf8))
        }
    }

    @Test("the tool states the most operations a call takes")
    func descriptionStatesTheLimit() {
        #expect(CanvasEditTool { _, _, _ in .refused("x") }.tool.description.contains("500"))
    }

    private static var rect: [String: Any] { ["origin": ["x": 1, "y": 2], "size": ["width": 30, "height": 40]] }
    private static var run: [String: Any] { ["text": "Hi", "fontName": "Helvetica", "size": 12, "weight": 0, "colour": "#000000"] }
    private static var text: [String: Any] { ["runs": [run], "alignment": "leading"] }
    private static var stroke: [String: Any] { ["points": [["x": 1, "y": 2]], "width": 2, "colour": "#000000"] }

    private func decodesAsElementKind(_ kind: [String: Any]) -> Bool {
        let element: [String: Any] = [
            "id": "e", "revision": 0, "rect": Self.rect,
            "style": ["strokeWidth": 0, "cornerRadius": 0, "opacity": 1, "rotation": 0], "kind": kind,
        ]
        let operation: [String: Any] = ["op": "addElement", "element": element]
        guard let data = try? JSONSerialization.data(withJSONObject: operation) else { return false }
        return (try? JSONDecoder().decode(CanvasOperation.self, from: data)) != nil
    }

    private func expectRequiredMatchesTheDecoder(_ path: [String], body: [String: Any], wrap: ([String: Any]) -> [String: Any]) throws {
        let item = try operationSchema()
        let required = try required(["properties", "element", "properties", "kind", "properties"] + path, in: item)
        #expect(required == Set(body.keys))
        #expect(decodesAsElementKind(wrap(body)))
        for key in required {
            var without = body
            without[key] = nil
            #expect(!decodesAsElementKind(wrap(without)), "\(path) decoded without \(key)")
        }
    }

    @Test("a text and a note take the keys the schema requires, and no fewer")
    func textAndNoteKeys() throws {
        for kind in ["text", "note"] {
            try expectRequiredMatchesTheDecoder([kind, "properties", "_0"], body: Self.text) { [kind: ["_0": $0]] }
        }
    }

    @Test("a shape takes the keys the schema requires, and no fewer")
    func shapeKeys() throws {
        try expectRequiredMatchesTheDecoder(["shape", "properties", "_0"], body: ["kind": "arrow"]) { ["shape": ["_0": $0]] }
    }

    @Test("an image takes the keys the schema requires, and no fewer")
    func imageKeys() throws {
        try expectRequiredMatchesTheDecoder(["image"], body: ["path": "a.png"]) { ["image": $0] }
    }

    @Test("a stroke takes the keys the schema requires, and no fewer")
    func strokeKeys() throws {
        try expectRequiredMatchesTheDecoder(["stroke", "properties", "_0"], body: Self.stroke) { ["stroke": ["_0": $0]] }
    }

    private func propertyNames(_ node: JSONValue) throws -> Set<String> {
        guard case .object(let fields) = node, case .object(let properties)? = fields["properties"] else { throw SchemaMissing() }
        return Set(properties.keys)
    }

    private func encodedKeys(_ value: some Encodable) throws -> Set<String> {
        guard case .object(let fields)? = JSONValue.parse(try JSONEncoder().encode(value)) else { throw SchemaMissing() }
        return Set(fields.keys)
    }

    private var fullShadow: CanvasShadowPatch { CanvasShadowPatch(offsetX: 1, offsetY: 1, radius: 1, colour: "#000000") }

    private var fullStyle: CanvasStylePatch {
        CanvasStylePatch(
            fill: "#000000", clearFill: true, stroke: "#000000", clearStroke: true, strokeWidth: 1,
            cornerRadius: 1, opacity: 1, rotation: 1, shadow: fullShadow, clearShadow: true
        )
    }

    @Test("the patch schemas name exactly the properties the patches decode")
    func patchPropertiesMatchTheDecoder() throws {
        guard case .array(let patches) = try node(["properties", "patch", "anyOf"], in: try operationSchema()), patches.count == 2 else {
            throw SchemaMissing()
        }
        let frame = CanvasFramePatch(name: "F", rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), fill: "#000000")
        let element = CanvasElementPatch(
            frameID: CanvasFrameID("f"), clearFrame: true, rect: CanvasRect(x: 0, y: 0, width: 1, height: 1),
            style: fullStyle, kind: .image(path: "a.png")
        )
        #expect(try propertyNames(patches[0]) == encodedKeys(frame))
        #expect(try propertyNames(patches[1]) == encodedKeys(element))
        #expect(try propertyNames(try node(["properties", "style"], in: patches[1])) == encodedKeys(fullStyle))
        #expect(try propertyNames(try node(["properties", "style", "properties", "shadow"], in: patches[1])) == encodedKeys(fullShadow))
    }
}
