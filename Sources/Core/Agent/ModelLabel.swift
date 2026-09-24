import Foundation

public enum ModelLabel {
    public static func readable(_ id: String) -> String {
        let parts = id.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." })

        guard !parts.isEmpty else { return id }

        let named = parts.drop { $0.lowercased() == "claude" }
        let kept = named.isEmpty ? parts[...] : named

        return join(kept.map(tidy))
    }

    private static func tidy(_ part: Substring) -> String {
        let bracketed = part.replacing("[", with: " (").replacing("]", with: ")")

        if bracketed.caseInsensitiveCompare("gpt") == .orderedSame { return "GPT" }

        guard let first = bracketed.first, first.isLetter else { return String(bracketed) }

        return first.uppercased() + bracketed.dropFirst()
    }

    private static func join(_ parts: [String]) -> String {
        var result = ""

        for (index, part) in parts.enumerated() {
            if index > 0 {
                result += isNumeric(part) && isNumeric(parts[index - 1]) ? "." : " "
            }
            result += part
        }

        return result
    }

    private static func isNumeric(_ part: String) -> Bool {
        let counted = part.prefix { $0 != " " }
        return !counted.isEmpty && counted.allSatisfy(\.isNumber)
    }
}
