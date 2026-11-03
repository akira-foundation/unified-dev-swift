import Foundation

enum CanvasOperationSchema {
    private static func string(_ description: String? = nil, options: [String]? = nil) -> JSONValue {
        var fields: [String: JSONValue] = ["type": .string("string")]
        if let description { fields["description"] = .string(description) }
        if let options { fields["enum"] = .array(options.map { .string($0) }) }
        return .object(fields)
    }

    private static let number = JSONValue.object(["type": .string("number")])

    private static func object(_ properties: [String: JSONValue], required: [String] = []) -> JSONValue {
        var fields: [String: JSONValue] = ["type": .string("object"), "properties": .object(properties)]
        if !required.isEmpty { fields["required"] = .array(required.map { .string($0) }) }
        return .object(fields)
    }

    private static let point = object(["x": number, "y": number], required: ["x", "y"])

    private static let rect = object([
        "origin": point,
        "size": object(["width": number, "height": number], required: ["width", "height"]),
    ], required: ["origin", "size"])

    private static let colour = string("#RRGGBB or #RRGGBBAA.")

    private static let textRun = object([
        "text": string(), "fontName": string(), "size": number, "weight": number, "colour": colour,
    ], required: ["text", "fontName", "size", "weight", "colour"])

    private static let text = object([
        "runs": .object(["type": .string("array"), "items": textRun]),
        "alignment": string(options: ["leading", "centre", "trailing"]),
    ], required: ["runs"])

    private static let kind = JSONValue.object([
        "type": .string("object"),
        "description": .string("Exactly one key: text, note, shape, image or stroke."),
        "properties": .object([
            "text": object(["_0": text], required: ["_0"]),
            "note": object(["_0": text], required: ["_0"]),
            "shape": object(
                ["_0": object(["kind": string(options: ["rectangle", "ellipse", "line", "arrow"])], required: ["kind"])],
                required: ["_0"]
            ),
            "image": object(["path": string("Workspace-relative or beside the document.")], required: ["path"]),
            "stroke": object(
                ["_0": object([
                    "points": .object(["type": .string("array"), "items": point]), "width": number, "colour": colour,
                ], required: ["points", "width", "colour"])],
                required: ["_0"]
            ),
        ]),
    ])

    private static let shadow = object([
        "offsetX": number, "offsetY": number, "radius": number, "colour": colour,
    ])

    private static let style = object([
        "fill": colour, "stroke": colour, "strokeWidth": number, "cornerRadius": number,
        "opacity": .object(["type": .string("number"), "minimum": .integer(0), "maximum": .integer(1)]),
        "rotation": .object(["type": .string("number"), "description": .string("Degrees.")]),
        "shadow": object([
            "offsetX": number, "offsetY": number, "radius": number, "colour": colour,
        ], required: ["offsetX", "offsetY", "radius", "colour"]),
    ], required: ["strokeWidth", "cornerRadius", "opacity", "rotation"])

    private static let stylePatch = object([
        "fill": colour, "clearFill": bool, "stroke": colour, "clearStroke": bool,
        "strokeWidth": number, "cornerRadius": number, "opacity": number, "rotation": number,
        "shadow": shadow, "clearShadow": bool,
    ])

    private static let bool = JSONValue.object(["type": .string("boolean")])

    private static let frame = object([
        "id": string("A new, unique id."), "name": string(), "rect": rect,
        "fill": colour, "revision": .object(["type": .string("integer"), "description": .string("0 when new.")]),
    ], required: ["id", "name", "rect"])

    private static let element = object([
        "id": string("A new, unique id."), "frameID": string("The frame it sits in; its rect is relative to it."),
        "revision": .object(["type": .string("integer"), "description": .string("0 when new.")]),
        "rect": rect, "style": style, "kind": kind,
    ], required: ["id", "rect", "style", "kind"])

    private static let framePatch = object(["name": string(), "rect": rect, "fill": colour])

    private static let elementPatch = object([
        "frameID": string("Move the element into this frame."), "clearFrame": bool,
        "rect": rect, "style": stylePatch, "kind": kind,
    ])

    private static let revision = JSONValue.object([
        "type": .string("integer"),
        "description": .string("The revision you read. Required to update or delete."),
    ])

    static let operation = object([
        "op": string(
            options: ["addFrame", "updateFrame", "deleteFrame", "addElement", "updateElement", "deleteElement", "reorder"]
        ),
        "id": string("The frame or element the operation is about."),
        "expectedRevision": revision,
        "frame": frame,
        "element": element,
        "patch": .object([
            "description": .string("For updateFrame a frame patch, for updateElement an element patch."),
            "oneOf": .array([framePatch, elementPatch]),
        ]),
        "toIndex": .object(["type": .string("integer"), "description": .string("0 is the back.")]),
    ], required: ["op"])
}
