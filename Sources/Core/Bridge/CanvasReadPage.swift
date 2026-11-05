import Foundation

struct CanvasReadPage {
    static let characterLimit = ChatTranscriptPage.characterLimit
    static let fieldLimit = 2_000
    private static let frameShare = 8_000
    private static let commentShare = 8_000
    private static let measuredSizeLength = 60
    private static let closingLinesLength = 500

    private var shortening = CanvasAnswerShortening()

    private(set) var frames: [JSONValue] = []
    private(set) var comments: [JSONValue] = []
    private(set) var elements: [JSONValue] = []
    private(set) var cut: [String] = []
    private(set) var nextOffset: Int?
    private(set) var nextFrameOffset: Int?

    init(frames allFrames: [JSONValue], comments allComments: [JSONValue], elements allElements: [JSONValue], offset: Int, frameOffset: Int = 0) {
        var used = 0
        takeFrames(allFrames, from: frameOffset, used: &used)
        comments = taking(allComments, within: Self.commentShare, used: &used)
        if comments.count < allComments.count { cut.append("\(allComments.count - comments.count) more open comments are not listed here.") }
        takeElements(allElements, from: offset, within: Self.characterLimit - used)
        if let sentence = shortening.sentence { cut.append(sentence) }
    }

    private mutating func taking(_ items: [JSONValue], within share: Int, used: inout Int) -> [JSONValue] {
        var kept: [JSONValue] = []
        var left = share
        for item in items {
            let value = shortening.shortened(item)
            let length = Self.length(of: value)
            guard length <= left else { break }
            kept.append(value)
            left -= length
            used += length
        }
        return kept
    }

    private mutating func takeFrames(_ all: [JSONValue], from offset: Int, used: inout Int) {
        var left = Self.frameShare
        var index = offset
        while index < all.count {
            let before = shortening.count
            var value = shortening.shortened(all[index])
            var length = Self.length(of: value)
            var tooLargeLine: String?
            if length > Self.frameShare {
                shortening.count = before
                value = Self.namedFrame(all[index])
                let line = "Frame \(value["id"]?.stringValue ?? "?") is too large to list, so only its place is given. See it with canvas_render."
                tooLargeLine = line
                length = Self.length(of: value) + line.count * 5 / 4
            }
            guard length <= left else {
                shortening.count = before
                break
            }
            frames.append(value)
            if let tooLargeLine { cut.append(tooLargeLine) }
            left -= length
            used += length
            index += 1
        }
        guard index < all.count else { return }
        nextFrameOffset = index
        cut.append("This answer holds frames \(offset) to \(index - 1) of \(all.count). Call canvas_read again with frameOffset \(index) for the rest.")
    }

    private mutating func takeElements(_ all: [JSONValue], from offset: Int, within budget: Int) {
        let budget = budget - Self.closingLinesLength
        var left = budget
        var index = offset
        while index < all.count {
            let before = shortening.count
            var value = shortening.shortened(all[index])
            var length = Self.length(of: value) + Self.measuredSizeLength
            var tooLargeLine: String?
            if length > budget {
                shortening.count = before
                value = shortening.shortened(Self.named(all[index]))
                let name = value["id"]?.stringValue ?? "?"
                let line = "Element \(name) is too large to list, so only its place is given. See it with canvas_render."
                tooLargeLine = line
                length = Self.length(of: value) + Self.measuredSizeLength + line.count * 5 / 4
            }
            guard length <= left else {
                shortening.count = before
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

    private static func named(_ element: JSONValue) -> JSONValue {
        guard case .object(let fields) = element else { return element }
        var kept = fields.filter { ["frameID", "rect", "revision"].contains($0.key) }
        kept["id"] = .string(CanvasFileText.plain(fields["id"]?.stringValue ?? ""))
        kept["tooLarge"] = .bool(true)
        return .object(kept)
    }

    private static func namedFrame(_ frame: JSONValue) -> JSONValue {
        guard case .object(let fields) = frame else { return frame }
        var kept = fields.filter { ["rect", "revision"].contains($0.key) }
        kept["id"] = .string(CanvasFileText.plain(fields["id"]?.stringValue ?? ""))
        kept["name"] = .string(CanvasFileText.plain(fields["name"]?.stringValue ?? ""))
        kept["tooLarge"] = .bool(true)
        return .object(kept)
    }

    static func length(of value: JSONValue) -> Int {
        BridgeToolResult.json(value).text.count * 5 / 4
    }
}
