import Foundation

enum TextCap {
    static let lineCap = 500
    static let characterCap = 400_000

    static func cap(
        _ text: String,
        lines: Int,
        characters characterLimit: Int = characterCap
    ) -> (text: String, truncated: Bool) {
        var seen = 0
        var index = text.startIndex
        var characters = 0

        while index < text.endIndex {
            if characters >= min(characterLimit, characterCap) {
                return (String(text[text.startIndex..<index]), true)
            }
            if text[index] == "\n" {
                seen += 1
                if seen >= lines {
                    return (String(text[text.startIndex..<index]), true)
                }
            }
            index = text.index(after: index)
            characters += 1
        }
        return (text, false)
    }
}
