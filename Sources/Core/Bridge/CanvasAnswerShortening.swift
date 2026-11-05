import Foundation

struct CanvasAnswerShortening {
    var count = 0

    var sentence: String? {
        guard count > 0 else { return nil }
        return "\(count) long \(count == 1 ? "value was" : "values were") shortened to \(CanvasReadPage.fieldLimit) characters."
    }

    mutating func shortened(_ value: JSONValue) -> JSONValue {
        switch value {
        case .string(let text) where CanvasTextLimit.length(of: text) > CanvasReadPage.fieldLimit:
            count += 1
            return .string(CanvasTextLimit.cut(text, to: CanvasReadPage.fieldLimit))
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
}
