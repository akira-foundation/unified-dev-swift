import Foundation

public enum RepoMonogram {
    public static func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }

        if isPictograph(first) { return String(first) }

        let words = words(in: trimmed)
        let named = words.filter { $0[0].isLetter }

        if named.count >= 2 {
            return String([upper(named[0][0]), upper(named[1][0])])
        }
        if let only = named.first {
            return String(only.prefix(2).map(upper))
        }
        if let digits = words.first {
            return String(digits.prefix(2).map(upper))
        }
        return ""
    }

    public static func mark(in name: String) -> String {
        let initials = initials(for: name)
        guard initials.count == 1, let character = initials.first,
              !character.isLetter, !character.isNumber else { return "" }
        return initials
    }

    public static func nameWithoutMark(_ name: String) -> String {
        let mark = mark(in: name)
        guard !mark.isEmpty else { return name }
        return String(name.dropFirst(mark.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func words(in name: String) -> [[Character]] {
        var words: [[Character]] = []
        var current: [Character] = []

        func flush() {
            guard !current.isEmpty else { return }
            words.append(current)
            current = []
        }

        for character in name {
            guard character.isLetter || character.isNumber else {
                flush()
                continue
            }
            if character.isUppercase, let previous = current.last, !previous.isUppercase {
                flush()
            }
            current.append(character)
        }
        flush()
        return words
    }

    private static func upper(_ character: Character) -> Character {
        character.uppercased().first ?? character
    }

    private static func isPictograph(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        if scalar.properties.isEmojiPresentation { return true }
        return scalar.properties.isEmoji && character.unicodeScalars.count > 1
    }
}
