import Foundation

public enum ClaudeModelEntry {
    public enum Outcome: Sendable, Hashable {
        case accepted(String)
        case refused(String)

        public var id: String? {
            if case .accepted(let id) = self { return id }
            return nil
        }

        public var refusal: String? {
            if case .refused(let message) = self { return message }
            return nil
        }
    }

    public static let hint = "A family and a version, such as opus-5-5, or a full id, "
        + "such as claude-opus-5-5."

    public static func accept(_ typed: String) -> Outcome {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .refused("Write a model first. " + hint)
        }

        let id = ModelAlias.cliValue(for: trimmed.replacingOccurrences(of: ".", with: "-"))
        guard isShaped(id), names(aFamilyIn: id) else {
            return .refused("Unified Dev cannot read \(trimmed) as a Claude model. " + hint)
        }

        return .accepted(id)
    }

    static let idLimit = 64

    static func isShaped(_ id: String) -> Bool {
        id.count <= idLimit
            && id.allSatisfy(isAllowed)
            && !id.contains("--")
            && !id.hasPrefix("-")
            && !id.hasSuffix("-")
    }

    static func isAllowed(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || "-[]".contains(character))
    }

    static func names(aFamilyIn id: String) -> Bool {
        if ClaudeModelRank.recognises(id) { return true }
        guard id.hasPrefix("claude-") else { return false }
        let rest = id.dropFirst("claude-".count)
        return rest.contains(where: \.isLetter) && rest.contains(where: \.isNumber)
    }
}
