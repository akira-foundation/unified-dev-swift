import Foundation

struct CanvasConflictPage {
    private static let closingLinesLength = 500

    private(set) var entries: [JSONValue] = []
    private(set) var cut: [String] = []

    init(_ conflicts: [CanvasConflict]) {
        var shortening = CanvasAnswerShortening()
        var left = CanvasReadPage.characterLimit - Self.closingLinesLength
        var withoutBody = 0
        for conflict in conflicts {
            let before = shortening.count
            var entry = shortening.shortened(Self.whole(conflict))
            var length = CanvasReadPage.length(of: entry)
            if length > left {
                shortening.count = before
                entry = shortening.shortened(Self.bare(conflict))
                length = CanvasReadPage.length(of: entry)
                withoutBody += 1
            }
            guard length <= left else {
                shortening.count = before
                withoutBody -= 1
                break
            }
            entries.append(entry)
            left -= length
        }
        if withoutBody > 0 {
            cut.append("Only the revision of \(withoutBody) of these is given, because the current state would be too large. See it with canvas_read.")
        }
        if entries.count < conflicts.count {
            cut.append("\(conflicts.count - entries.count) more conflicts are not listed here. See them with canvas_read.")
        }
        if let sentence = shortening.sentence { cut.append(sentence) }
    }

    private static func bare(_ conflict: CanvasConflict) -> JSONValue {
        .object(["target": .string(conflict.target), "revision": .integer(conflict.revision)])
    }

    private static func whole(_ conflict: CanvasConflict) -> JSONValue {
        guard case .object(var fields) = bare(conflict) else { return bare(conflict) }
        switch conflict.current {
        case .element(let element): fields["element"] = CanvasDocumentJSON.element(element)
        case .frame(let frame): fields["frame"] = (try? JSONEncoder().encode(frame)).flatMap(JSONValue.parse)
        }
        return .object(fields)
    }
}
