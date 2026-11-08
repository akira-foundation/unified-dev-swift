import Foundation

public struct CanvasRunChange: Sendable, Hashable {
    public var fontName: String?
    public var size: Double?
    public var weight: Double?
    public var colour: String?

    public init(fontName: String? = nil, size: Double? = nil, weight: Double? = nil, colour: String? = nil) {
        self.fontName = fontName
        self.size = size
        self.weight = weight
        self.colour = colour
    }

    func applied(to run: CanvasTextRun) -> CanvasTextRun {
        var result = run
        if let fontName { result.fontName = fontName }
        if let size { result.size = size }
        if let weight { result.weight = weight }
        if let colour { result.colour = colour }
        return result
    }
}

public enum CanvasTextStyling {
    public static func applying(_ change: CanvasRunChange, range: Range<Int>, to text: CanvasText) -> CanvasText {
        let styled = characters(of: text)
        let lower = max(0, range.lowerBound)
        let upper = min(styled.count, range.upperBound)
        guard lower < upper else { return text }
        let changed = styled.enumerated().map { offset, entry in
            (entry.character, (lower..<upper).contains(offset) ? change.applied(to: entry.style) : entry.style)
        }
        return CanvasText(runs: regrouped(changed), alignment: text.alignment)
    }

    public static func operations(
        applying change: CanvasRunChange, to ids: [CanvasElementID], in document: CanvasDocument
    ) -> [CanvasOperation] {
        ids.compactMap { id in
            guard let element = document.elements.first(where: { $0.id == id }), let text = element.text else { return nil }
            let styled = applying(change, range: 0..<text.runs.map(\.text).joined().count, to: text)
            return .updateElement(id, expectedRevision: nil, CanvasElementPatch(kind: element.kind(replacingTextWith: styled)))
        }
    }

    public static func normalised(_ runs: [CanvasTextRun], alignment: CanvasText.Alignment = .leading) -> CanvasText {
        var result: [CanvasTextRun] = []
        for run in runs where !run.text.isEmpty {
            if let last = result.last, sameStyle(last, run) {
                result[result.count - 1].text += run.text
            } else {
                result.append(run)
            }
        }
        if result.isEmpty, let first = runs.first {
            result = [CanvasTextRun(text: "", fontName: first.fontName, size: first.size, weight: first.weight, colour: first.colour)]
        }
        return CanvasText(runs: result, alignment: alignment)
    }

    public static func characterRange(of range: NSRange, in text: String) -> Range<Int> {
        guard let swiftRange = Range(range, in: text) else { return 0..<0 }
        let lower = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
        let upper = text.distance(from: text.startIndex, to: swiftRange.upperBound)
        return lower..<upper
    }

    private static func characters(of text: CanvasText) -> [(character: Character, style: CanvasTextRun)] {
        let joined = text.runs.map(\.text).joined()
        var boundaries: [Int] = []
        var total = 0
        for run in text.runs {
            total += run.text.utf8.count
            boundaries.append(total)
        }
        var position = 0
        return joined.map { character in
            let index = boundaries.firstIndex { position < $0 } ?? max(text.runs.count - 1, 0)
            position += String(character).utf8.count
            return (character, text.runs[index])
        }
    }

    private static func regrouped(_ characters: [(Character, CanvasTextRun)]) -> [CanvasTextRun] {
        var result: [CanvasTextRun] = []
        for (character, style) in characters {
            if let last = result.last, sameStyle(last, style) {
                result[result.count - 1].text.append(character)
            } else {
                var run = style
                run.text = String(character)
                result.append(run)
            }
        }
        return result
    }

    private static func sameStyle(_ lhs: CanvasTextRun, _ rhs: CanvasTextRun) -> Bool {
        lhs.fontName == rhs.fontName && lhs.size == rhs.size && lhs.weight == rhs.weight && lhs.colour == rhs.colour
    }
}
