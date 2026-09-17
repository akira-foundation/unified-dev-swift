import Foundation

public struct PromptRender: Sendable, Hashable {
    public var text: String
    public var missing: [String]
    public var unknown: [String]

    public init(text: String, missing: [String] = [], unknown: [String] = []) {
        self.text = text
        self.missing = missing
        self.unknown = unknown
    }
}

public enum PromptTemplate {
    public static let open = "{{"
    public static let close = "}}"

    public static func token(_ name: String) -> String {
        "\(open)\(name)\(close)"
    }

    public static func render(_ template: String, values: [String: String]) -> PromptRender {
        var text = ""
        var missing: [String] = []
        var unknown: [String] = []
        var cursor = template.startIndex

        while let opening = template.range(of: open, range: cursor..<template.endIndex) {
            guard let closing = template.range(of: close, range: opening.upperBound..<template.endIndex)
            else { break }

            let raw = String(template[opening.upperBound..<closing.lowerBound])
            let name = raw.trimmingCharacters(in: .whitespaces)

            guard isVariableName(name) else {
                text += template[cursor..<closing.upperBound]
                cursor = closing.upperBound
                continue
            }

            text += template[cursor..<opening.lowerBound]

            if let value = values[name] {
                if value.isEmpty { append(name, to: &missing) }
                text += value
            } else {
                append(name, to: &unknown)
                text += template[opening.lowerBound..<closing.upperBound]
            }

            cursor = closing.upperBound
        }

        text += template[cursor...]
        return PromptRender(text: text, missing: missing, unknown: unknown)
    }

    public static func variableNames(in template: String) -> [String] {
        let render = render(template, values: [:])
        return render.unknown
    }

    static func isVariableName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private static func append(_ name: String, to list: inout [String]) {
        guard !list.contains(name) else { return }
        list.append(name)
    }
}
