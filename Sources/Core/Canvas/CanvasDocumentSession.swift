import Foundation

public struct CanvasDocumentSession: Sendable, Equatable {
    public private(set) var document: CanvasDocument

    public init(document: CanvasDocument) {
        self.document = document
    }

    public mutating func apply(_ operations: [CanvasOperation], by author: CanvasAuthor) -> CanvasEditOutcome {
        var batch = CanvasOperationBatch(original: document, author: author)
        for (index, operation) in operations.enumerated() {
            do {
                try batch.perform(operation)
            } catch let invalid as CanvasOperationBatch.Invalid {
                return .invalid("Operation at index \(index): \(invalid.message)")
            } catch {
                return .invalid("Operation at index \(index) failed.")
            }
        }
        guard batch.conflicts.isEmpty else { return .conflict(batch.conflicts) }
        document = batch.document
        return .applied(document)
    }

    public mutating func beginEditing(_ element: CanvasElementID) {
        guard let index = document.elements.firstIndex(where: { $0.id == element }) else { return }
        document.elements[index].revision += 1
    }
}

struct CanvasOperationBatch {
    struct Invalid: Error {
        let message: String
    }

    let original: CanvasDocument
    let author: CanvasAuthor
    private(set) var document: CanvasDocument
    private(set) var conflicts: [CanvasConflict] = []

    init(original: CanvasDocument, author: CanvasAuthor) {
        self.original = original
        self.author = author
        document = original
    }

    mutating func perform(_ operation: CanvasOperation) throws {
        switch operation {
        case .addFrame(let frame):
            try addFrame(frame)
        case .updateFrame(let id, let expected, let patch):
            try updateFrame(id, expected: expected, patch: patch)
        case .deleteFrame(let id, let expected):
            try deleteFrame(id, expected: expected)
        case .addElement(let element):
            try addElement(element)
        case .updateElement(let id, let expected, let patch):
            try updateElement(id, expected: expected, patch: patch)
        case .deleteElement(let id, let expected):
            try deleteElement(id, expected: expected)
        case .reorder(let id, let index):
            try reorder(id, to: index)
        }
    }

    private mutating func addFrame(_ frame: CanvasFrame) throws {
        guard !document.frames.contains(where: { $0.id == frame.id }) else {
            throw Invalid(message: "frame '\(frame.id.rawValue)' already exists.")
        }
        try Self.validate(rect: frame.rect, of: "frame '\(frame.id.rawValue)'")
        document.frames.append(frame)
    }

    private mutating func updateFrame(_ id: CanvasFrameID, expected: Int?, patch: CanvasFramePatch) throws {
        guard let index = document.frames.firstIndex(where: { $0.id == id }) else {
            throw Invalid(message: "there is no frame '\(id.rawValue)'.")
        }
        guard try passes(expected, id: id.rawValue, original: original.frames.first { $0.id == id }.map { ($0.revision, .frame($0)) }) else { return }
        var updated = patch.applied(to: document.frames[index])
        try Self.validate(rect: updated.rect, of: "frame '\(id.rawValue)'")
        updated.revision = document.frames[index].revision + 1
        document.frames[index] = updated
    }

    private mutating func deleteFrame(_ id: CanvasFrameID, expected: Int?) throws {
        guard document.frames.contains(where: { $0.id == id }) else {
            throw Invalid(message: "there is no frame '\(id.rawValue)'.")
        }
        guard try passes(expected, id: id.rawValue, original: original.frames.first { $0.id == id }.map { ($0.revision, .frame($0)) }) else { return }
        document.frames.removeAll { $0.id == id }
        document.elements.removeAll { $0.frameID == id }
    }

    private mutating func addElement(_ element: CanvasElement) throws {
        guard !document.elements.contains(where: { $0.id == element.id }) else {
            throw Invalid(message: "element '\(element.id.rawValue)' already exists.")
        }
        try validate(element)
        document.elements.append(element)
    }

    private mutating func updateElement(_ id: CanvasElementID, expected: Int?, patch: CanvasElementPatch) throws {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else {
            throw Invalid(message: "there is no element '\(id.rawValue)'.")
        }
        guard try passes(expected, id: id.rawValue, original: original.elements.first { $0.id == id }.map { ($0.revision, .element($0)) }) else { return }
        var updated = patch.applied(to: document.elements[index])
        try validate(updated)
        updated.revision = document.elements[index].revision + 1
        document.elements[index] = updated
    }

    private mutating func deleteElement(_ id: CanvasElementID, expected: Int?) throws {
        guard document.elements.contains(where: { $0.id == id }) else {
            throw Invalid(message: "there is no element '\(id.rawValue)'.")
        }
        guard try passes(expected, id: id.rawValue, original: original.elements.first { $0.id == id }.map { ($0.revision, .element($0)) }) else { return }
        document.elements.removeAll { $0.id == id }
    }

    private mutating func reorder(_ id: CanvasElementID, to target: Int) throws {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else {
            throw Invalid(message: "there is no element '\(id.rawValue)'.")
        }
        var moved = document.elements.remove(at: index)
        moved.revision += 1
        document.elements.insert(moved, at: min(max(target, 0), document.elements.count))
    }

    private mutating func passes(
        _ expected: Int?, id: String, original: (Int, CanvasConflict.Current)?
    ) throws -> Bool {
        guard author == .agent, let (revision, current) = original else { return true }
        guard let expected else {
            throw Invalid(message: "'\(id)' needs expectedRevision, read it with canvas_read.")
        }
        guard expected == revision else {
            if !conflicts.contains(where: { $0.target == id }) {
                conflicts.append(CanvasConflict(target: id, revision: revision, current: current))
            }
            return false
        }
        return true
    }

    private func validate(_ element: CanvasElement) throws {
        let name = "element '\(element.id.rawValue)'"
        try Self.validate(rect: element.rect, of: name)
        if let frameID = element.frameID, !document.frames.contains(where: { $0.id == frameID }) {
            throw Invalid(message: "\(name) is in frame '\(frameID.rawValue)', which does not exist.")
        }
        let numbers = [
            element.style.strokeWidth, element.style.cornerRadius, element.style.opacity, element.style.rotation,
        ]
        guard numbers.allSatisfy(\.isFinite) else {
            throw Invalid(message: "\(name) has a style value that is not a finite number.")
        }
        guard element.style.strokeWidth >= 0, element.style.cornerRadius >= 0 else {
            throw Invalid(message: "\(name) has a negative stroke width or corner radius.")
        }
    }

    private static func validate(rect: CanvasRect, of name: String) throws {
        let values = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
        guard values.allSatisfy(\.isFinite) else {
            throw Invalid(message: "\(name) has a position or size that is not a finite number.")
        }
        guard rect.size.width >= 0, rect.size.height >= 0 else {
            throw Invalid(message: "\(name) has a negative size.")
        }
    }
}
