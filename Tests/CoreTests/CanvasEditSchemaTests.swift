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

    @Test("the schema names every operation the decoder knows")
    func schemaListsEveryOperation() {
        let listing = CanvasEditTool { _, _, _ in .refused("x") }.tool.listing
        let text = String(describing: listing)

        for name in ["addFrame", "updateFrame", "deleteFrame", "addElement", "updateElement", "deleteElement", "reorder"] {
            #expect(text.contains(name))
        }
        #expect(text.contains("500"))
    }
}
