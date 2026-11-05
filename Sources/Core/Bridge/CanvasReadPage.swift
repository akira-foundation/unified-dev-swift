import Foundation

struct CanvasReadPage {
    static let characterLimit = ChatTranscriptPage.characterLimit
    static let fieldLimit = 2_000
    private static let frameShare = 8_000
    private static let commentShare = 8_000
    private static let measuredSizeLength = 60
    private static let closingLinesLength = 400

    private var valuesShortened = 0

    private(set) var frames: [JSONValue] = []
    private(set) var comments: [JSONValue] = []
    private(set) var elements: [JSONValue] = []
    private(set) var cut: [String] = []
    private(set) var nextOffset: Int?

    init(frames allFrames: [JSONValue], comments allComments: [JSONValue], elements allElements: [JSONValue], offset: Int) {
        var used = 0
        frames = taking(allFrames, within: Self.frameShare, used: &used)
        if frames.count < allFrames.count { cut.append("\(allFrames.count - frames.count) more frames are not listed here.") }
        comments = taking(allComments, within: Self.commentShare, used: &used)
        if comments.count < allComments.count { cut.append("\(allComments.count - comments.count) more open comments are not listed here.") }
        takeElements(allElements, from: offset, within: Self.characterLimit - used)
        if valuesShortened > 0 {
            cut.append("\(valuesShortened) long \(valuesShortened == 1 ? "value was" : "values were") shortened to \(Self.fieldLimit) characters.")
        }
    }

    private mutating func taking(_ items: [JSONValue], within share: Int, used: inout Int) -> [JSONValue] {
        var kept: [JSONValue] = []
        var left = share
        for item in items {
            let value = shortened(item)
            let length = Self.length(of: value)
            guard length <= left else { break }
            kept.append(value)
            left -= length
            used += length
        }
        return kept
    }

    private mutating func takeElements(_ all: [JSONValue], from offset: Int, within budget: Int) {
        let budget = budget - Self.closingLinesLength
        var left = budget
        var index = offset
        while index < all.count {
            let before = valuesShortened
            var value = shortened(all[index])
            var length = Self.length(of: value) + Self.measuredSizeLength
            var tooLargeLine: String?
            if length > budget {
                valuesShortened = before
                value = shortened(Self.named(all[index]))
                let name = value["id"]?.stringValue ?? "?"
                let line = "Element \(name) is too large to list, so only its place is given. See it with canvas_render."
                tooLargeLine = line
                length = Self.length(of: value) + Self.measuredSizeLength + line.count * 5 / 4
            }
            guard length <= left else {
                valuesShortened = before
                break
            }
            elements.append(value)
            if let tooLargeLine { cut.append(tooLargeLine) }
            left -= length
            index += 1
        }
        guard index < all.count else { return }
        nextOffset = index
        cut.append("This answer holds elements \(offset) to \(index - 1) of \(all.count). Call canvas_read again with offset \(index) for the rest.")
    }

    private mutating func shortened(_ value: JSONValue) -> JSONValue {
        switch value {
        case .string(let text) where text.count > Self.fieldLimit:
            valuesShortened += 1
            return .string(String(text.prefix(Self.fieldLimit)))
        case .array(let items):
            var kept: [JSONValue] = []
            for item in items { kept.append(shortened(item)) }
            return .array(kept)
        case .object(let fields):
            var kept: [String: JSONValue] = [:]
            for (key, field) in fields { kept[key] = shortened(field) }
            return .object(kept)
        default:
            return value
        }
    }

    private static func named(_ element: JSONValue) -> JSONValue {
        guard case .object(let fields) = element else { return element }
        var kept = fields.filter { ["frameID", "rect", "revision"].contains($0.key) }
        kept["id"] = .string(CanvasFileText.plain(fields["id"]?.stringValue ?? ""))
        kept["tooLarge"] = .bool(true)
        return .object(kept)
    }

    private static func length(of value: JSONValue) -> Int {
        BridgeToolResult.json(value).text.count * 5 / 4
    }
}
