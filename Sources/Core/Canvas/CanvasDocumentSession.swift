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
        let points = batch.document.strokePointCount
        if points > CanvasStrokeBuilder.maximumDocumentPoints, points > document.strokePointCount {
            return .invalid("A canvas takes at most \(CanvasStrokeBuilder.maximumDocumentPoints) stroke points in all, and this would make \(points).")
        }
        document = batch.document
        return .applied(document)
    }

    public mutating func restore(_ restored: CanvasDocument) {
        document = restored
    }

    public mutating func beginEditing(_ element: CanvasElementID) {
        guard let index = document.elements.firstIndex(where: { $0.id == element }) else { return }
        document.elements[index].revision += 1
        guard let frameID = document.elements[index].frameID,
              let frame = document.frames.firstIndex(where: { $0.id == frameID }) else { return }
        document.frames[frame].revision += 1
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
        try Self.validate(frame: frame.rect, of: "frame '\(frame.id.rawValue)'")
        try validateColours([frame.fill], of: "frame '\(frame.id.rawValue)'")
        document.frames.append(frame)
    }

    private mutating func updateFrame(_ id: CanvasFrameID, expected: Int?, patch: CanvasFramePatch) throws {
        let index = try frameIndex(id)
        guard try passes(expected, id: id.rawValue, original: originalFrame(id)) else { return }
        var updated = patch.applied(to: document.frames[index])
        if patch.rect != nil { try Self.validate(frame: updated.rect, of: "frame '\(id.rawValue)'") }
        try validateColours(patch.fill.map { [$0] } ?? [], of: "frame '\(id.rawValue)'")
        updated.revision = document.frames[index].revision + 1
        document.frames[index] = updated
    }

    private mutating func deleteFrame(_ id: CanvasFrameID, expected: Int?) throws {
        _ = try frameIndex(id)
        guard try passes(expected, id: id.rawValue, original: originalFrame(id)) else { return }
        let removed = Set(document.elements.filter { $0.frameID == id }.map(\.id))
        document.frames.removeAll { $0.id == id }
        document.elements.removeAll { $0.frameID == id }
        for index in document.comments.indices {
            if document.comments[index].frameID == id { document.comments[index].frameID = nil }
            if let element = document.comments[index].elementID, removed.contains(element) {
                document.comments[index].elementID = nil
            }
        }
    }

    private mutating func addElement(_ element: CanvasElement) throws {
        guard !document.elements.contains(where: { $0.id == element.id }) else {
            throw Invalid(message: "element '\(element.id.rawValue)' already exists.")
        }
        try validate(element, previousPoints: 0)
        try validateColours(element.colours, of: "element '\(element.id.rawValue)'")
        document.elements.append(element)
        touch(element.frameID)
    }

    private mutating func updateElement(_ id: CanvasElementID, expected: Int?, patch: CanvasElementPatch) throws {
        let index = try elementIndex(id)
        guard try passes(expected, id: id.rawValue, original: originalElement(id)) else { return }
        let before = document.elements[index]
        var updated = patch.applied(to: before)
        if patch.kind == nil, patch.rect != nil, case .stroke(let stroke) = updated.kind, updated.rect.size != before.rect.size {
            updated.kind = .stroke(CanvasStrokeBuilder.resized(stroke, from: before.rect.size, to: updated.rect.size))
        }
        try validate(updated, previousPoints: Self.pointCount(of: before))
        try validateColours(updated.colours.filter { !before.colours.contains($0) }, of: "element '\(id.rawValue)'")
        updated.revision = before.revision + 1
        document.elements[index] = updated
        touch(before.frameID)
        if updated.frameID != before.frameID { touch(updated.frameID) }
    }

    private mutating func deleteElement(_ id: CanvasElementID, expected: Int?) throws {
        let index = try elementIndex(id)
        guard try passes(expected, id: id.rawValue, original: originalElement(id)) else { return }
        let frameID = document.elements[index].frameID
        document.elements.remove(at: index)
        for position in document.comments.indices where document.comments[position].elementID == id {
            document.comments[position].elementID = nil
        }
        touch(frameID)
    }

    private mutating func reorder(_ id: CanvasElementID, to target: Int) throws {
        let index = try elementIndex(id)
        var moved = document.elements.remove(at: index)
        moved.revision += 1
        document.elements.insert(moved, at: min(max(target, 0), document.elements.count))
        touch(moved.frameID)
    }

    private func frameIndex(_ id: CanvasFrameID) throws -> Int {
        guard let index = document.frames.firstIndex(where: { $0.id == id }) else {
            throw Invalid(message: "there is no frame '\(id.rawValue)'.")
        }
        return index
    }

    private func elementIndex(_ id: CanvasElementID) throws -> Int {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else {
            throw Invalid(message: "there is no element '\(id.rawValue)'.")
        }
        return index
    }

    private func originalFrame(_ id: CanvasFrameID) -> (Int, CanvasConflict.Current)? {
        original.frames.first { $0.id == id }.map { ($0.revision, .frame($0)) }
    }

    private func originalElement(_ id: CanvasElementID) -> (Int, CanvasConflict.Current)? {
        original.elements.first { $0.id == id }.map { ($0.revision, .element($0)) }
    }

    private mutating func touch(_ frameID: CanvasFrameID?) {
        guard let frameID, let index = document.frames.firstIndex(where: { $0.id == frameID }) else { return }
        document.frames[index].revision += 1
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

    private static func pointCount(of element: CanvasElement) -> Int {
        guard case .stroke(let stroke) = element.kind else { return 0 }
        return stroke.points.count
    }

    private func validateColours(_ colours: [String], of name: String) throws {
        guard author == .agent, let bad = colours.first(where: { CanvasColour($0) == nil }) else { return }
        throw Invalid(message: "\(name) has the colour '\(bad)', and a colour is \"#RRGGBB\" or \"#RRGGBBAA\".")
    }

    private func validate(_ element: CanvasElement, previousPoints: Int) throws {
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
        guard (0...1).contains(element.style.opacity) else {
            throw Invalid(message: "\(name) has an opacity outside 0 to 1.")
        }
        if case .stroke(let stroke) = element.kind {
            guard stroke.width.isFinite, stroke.width >= 0 else {
                throw Invalid(message: "\(name) has a stroke width that is negative or not a finite number.")
            }
            guard stroke.points.count <= max(CanvasStrokeBuilder.maximumPoints, previousPoints) else {
                throw Invalid(message: "\(name) has \(stroke.points.count) stroke points, and a stroke takes at most \(CanvasStrokeBuilder.maximumPoints).")
            }
            guard stroke.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                throw Invalid(message: "\(name) has a stroke point that is not a finite number.")
            }
        }
    }

    private static func validate(frame rect: CanvasRect, of name: String) throws {
        try validate(rect: rect, of: name)
        let largest = CanvasFrameSize.maximum
        guard rect.size.width <= largest, rect.size.height <= largest else {
            throw Invalid(message: "\(name) is larger than \(Int(largest)) points a side.")
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
