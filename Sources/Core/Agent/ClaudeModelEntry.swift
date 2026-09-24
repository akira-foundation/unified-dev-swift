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
        guard isShaped(id), ClaudeModelRank.recognises(id) else {
            return .refused("Unified Dev cannot read \(trimmed) as a Claude model. " + hint)
        }

        return .accepted(id)
    }

    static let idLimit = 64

    static func isShaped(_ id: String) -> Bool {
        guard id.count <= idLimit else { return false }
        let stem = stem(of: id)
        return !stem.isEmpty
            && stem.allSatisfy(isAllowed)
            && !stem.contains("--")
            && !stem.hasPrefix("-")
            && !stem.hasSuffix("-")
    }

    static func stem(of id: String) -> Substring {
        for window in ClaudeModelRank.windows where id.hasSuffix("[\(window)]") {
            return id.dropLast(window.count + 2)
        }
        return id[...]
    }

    static func isAllowed(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || character == "-")
    }
}
