import Foundation

public enum CanvasEditToolName {
    public static let edit = "canvas_edit"
    public static let maxOperations = 500
}

public typealias CanvasEditApplying = @MainActor @Sendable (
    _ path: String, _ operations: [CanvasOperation], _ workspaceID: WorkspaceID
) async -> CanvasEditOutcome

public struct CanvasEditTool: BridgeToolHandling {
    private let applying: CanvasEditApplying

    public init(_ applying: @escaping CanvasEditApplying) { self.applying = applying }

    public let roles = BridgeWorkspaceScope.roles
    public let tool = BridgeTool(
        name: CanvasEditToolName.edit,
        description: """
            Change a canvas document in this workspace by a list of operations, all or nothing. Works \
            whether or not the canvas is open in a tab, and does not open or focus the tab.

            Read first with canvas_read and pass the revisions you read as expectedRevision: every \
            update and delete of a frame or an element needs one. A reorder never conflicts. \
            A frame's revision rises when anything in it changes, so read again after your own \
            element edits before you update or delete that frame. If the person changed the item in the \
            meantime, nothing is applied: the answer has applied false and the current state of what \
            conflicted, so you can decide again. The person's edit wins, and nothing is merged.

            At most 500 operations a call. Every call is one undo step for the person, who can undo \
            all of it at once. A canvas that is corrupt, saved by a newer Unified Dev, no longer on \
            disk or with saving paused because the file changed is refused with the reason: the \
            person has to settle that in the tab first. Check what you drew with canvas_render.

            Each operation is an object with an 'op' and the keys that op uses:
            - addFrame: frame (a whole frame).
            - updateFrame: id, expectedRevision, patch (any of name, rect, fill).
            - deleteFrame: id, expectedRevision. Deletes the elements in it too.
            - addElement: element (a whole element).
            - updateElement: id, expectedRevision, patch (any of frameID, clearFrame, rect, style, kind).
            - deleteElement: id, expectedRevision.
            - reorder: id, toIndex. Index 0 is the back, the last index the front.
            A rect is {"origin": {"x", "y"}, "size": {"width", "height"}} in points; inside a frame an \
            element's origin is relative to the frame. Colours are "#RRGGBB" or "#RRGGBBAA". An element \
            has id, frameID (optional), revision (0 when new), rect, style and kind. A whole element's \
            style is {"fill", "stroke", "strokeWidth", "cornerRadius", "opacity", "rotation", "shadow"} \
            and must give the four numbers; fill, stroke and shadow are optional. A style patch takes \
            any of those, plus clearFill, clearStroke and clearShadow to remove them. A kind is one of \
            {"text": {"_0": {"runs": [{"text", "fontName", "size", \
            "weight", "colour"}], "alignment": "leading|centre|trailing"}}}, {"note": {"_0": text}}, \
            {"shape": {"_0": {"kind": "rectangle|ellipse|line|arrow"}}}, {"image": {"path": "a.png"}} \
            or {"stroke": {"_0": {"points": [{"x", "y"}], "width", "colour"}}}.

            'path' is workspace-relative or absolute and must name a canvas document inside this \
            workspace.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The canvas document to change, inside this workspace."),
                ]),
                "operations": .object([
                    "type": .string("array"),
                    "minItems": .integer(1),
                    "maxItems": .integer(CanvasEditToolName.maxOperations),
                    "items": CanvasOperationSchema.operation,
                    "description": .string("The operations to apply in order, all or nothing."),
                ]),
            ]),
            "required": .array([.string("path"), .string("operations")]),
        ])
    )

    public func call(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: CanvasEditToolName.edit, doing: "edits a canvas in")
            )
        }
        let path = request.stringParam("path")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else { return .failure("canvas_edit needs a non-empty 'path'.") }

        let operations: [CanvasOperation]
        switch Self.operations(in: request.param("operations")) {
        case .failure(let refusal): return .failure(refusal.sentence)
        case .success(let decoded): operations = decoded
        }

        switch await applying(path, operations, workspaceID) {
        case .invalid(let sentence):
            return .failure(sentence)
        case .conflict(let conflicts):
            return Self.conflictResult(conflicts)
        case .applied(let document):
            guard let fields = CanvasDocumentJSON.fields(of: document) else {
                return .failure("The edit was applied, but Unified Dev could not render the canvas as JSON. Read it with canvas_read.")
            }
            return .json(.object([
                "applied": .bool(true),
                "operationCount": .integer(operations.count),
                "document": .object(fields),
            ]))
        }
    }

    private struct Refusal: Error {
        let sentence: String
    }

    private static func operations(in value: JSONValue?) -> Result<[CanvasOperation], Refusal> {
        guard case .array(let items)? = value else {
            return .failure(Refusal(sentence: "canvas_edit needs 'operations', a list of operation objects."))
        }
        guard !items.isEmpty else {
            return .failure(Refusal(sentence: "canvas_edit needs at least one operation."))
        }
        guard items.count <= CanvasEditToolName.maxOperations else {
            return .failure(Refusal(
                sentence: "canvas_edit takes at most \(CanvasEditToolName.maxOperations) operations a call and got \(items.count). Nothing was applied; split it into several calls."
            ))
        }
        var decoded: [CanvasOperation] = []
        for (index, item) in items.enumerated() {
            do {
                decoded.append(try JSONDecoder().decode(CanvasOperation.self, from: JSONEncoder().encode(item)))
            } catch {
                return .failure(Refusal(
                    sentence: "Operation at index \(index) is malformed: \(describe(error)) Nothing was applied."
                ))
            }
        }
        return .success(decoded)
    }

    private static func describe(_ error: Error) -> String {
        guard let error = error as? DecodingError else { return "\(error.localizedDescription)." }
        switch error {
        case .keyNotFound(let key, _): return "it has no '\(key.stringValue)'."
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "'\(path(of: context))' is not the type this operation expects. \(context.debugDescription)"
        case .dataCorrupted(let context):
            return context.debugDescription.hasSuffix(".") ? context.debugDescription : context.debugDescription + "."
        @unknown default: return "it could not be read."
        }
    }

    private static func path(of context: DecodingError.Context) -> String {
        context.codingPath.map(\.stringValue).joined(separator: ".")
    }

    private static func conflictResult(_ conflicts: [CanvasConflict]) -> BridgeToolResult {
        let encoder = JSONEncoder()
        let entries: [JSONValue] = conflicts.compactMap { conflict in
            var fields: [String: JSONValue] = [
                "target": .string(conflict.target), "revision": .integer(conflict.revision),
            ]
            switch conflict.current {
            case .element(let element): fields["element"] = (try? encoder.encode(element)).flatMap(JSONValue.parse)
            case .frame(let frame): fields["frame"] = (try? encoder.encode(frame)).flatMap(JSONValue.parse)
            }
            return .object(fields)
        }
        let answer = JSONValue.object([
            "applied": .bool(false),
            "reason": .string(
                "The person changed these since you read them, so nothing was applied. "
                    + "Decide again from the current state, then send the operations with the new revisions."
            ),
            "conflicts": .array(entries),
        ])
        let body = BridgeToolResult.json(answer)
        return BridgeToolResult(text: body.text, isError: true)
    }
}
