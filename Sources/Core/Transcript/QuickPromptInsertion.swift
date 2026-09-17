import Foundation

public enum QuickPromptInsertion {
    public struct Result: Equatable, Sendable {
        public var text: String
        public var caret: Int

        public init(text: String, caret: Int) {
            self.text = text
            self.caret = caret
        }
    }

    public static func inserting(
        _ prompt: QuickPrompt, into draft: String, at caret: Int
    ) -> Result {
        inserting(prompt.text, into: draft, at: caret)
    }

    public static func inserting(_ prompt: String, into draft: String, at caret: Int) -> Result {
        let body = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let string = draft as NSString
        let at = min(max(caret, 0), string.length)
        guard !body.isEmpty else { return Result(text: draft, caret: at) }

        let before = at > 0
            ? string.substring(with: string.rangeOfComposedCharacterSequence(at: at - 1))
            : ""
        let after = at < string.length
            ? string.substring(with: string.rangeOfComposedCharacterSequence(at: at))
            : ""

        let lead = isBreak(before) ? "" : " "
        let trail = isBreak(after) ? "" : " "
        let written = lead + body + trail
        let text = string.replacingCharacters(in: NSRange(location: at, length: 0), with: written)

        let caret = at + ((lead + body) as NSString).length
        return Result(text: text, caret: caret)
    }

    private static func isBreak(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return true }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
