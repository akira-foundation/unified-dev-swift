import Foundation

public enum ModelAlias {
    private static let families = ClaudeModelRank.families

    public static func cliValue(for model: String) -> String {
        let named = ModelIdentifier.resolve(model).model
        let trimmed = named.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: "-")
        guard !trimmed.isEmpty else { return "opus" }

        if trimmed.hasPrefix("claude-") { return trimmed }
        if families.contains(trimmed) { return trimmed }

        guard let family = families.first(where: { trimmed.hasPrefix($0 + "-") }) else {
            return trimmed
        }

        var rest = String(trimmed.dropFirst(family.count + 1))

        var suffix = ""
        for marker in ["-1m", "-200k"] where rest.hasSuffix(marker) {
            suffix = "[" + marker.dropFirst() + "]"
            rest = String(rest.dropLast(marker.count))
            break
        }

        guard !rest.isEmpty, rest.allSatisfy({ $0.isNumber || $0 == "-" }) else {
            return trimmed
        }

        return "claude-\(family)-\(rest)\(suffix)"
    }
}
