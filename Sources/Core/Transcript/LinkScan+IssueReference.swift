import Foundation

extension LinkScan {
    static func issueReference(in text: String, at index: String.Index) -> DetectedLink? {
        var cursor = index
        let owner = run(of: text, from: &cursor, where: isOwnerCharacter)
        guard (1...39).contains(owner.count), owner.first != "-", owner.last != "-" else { return nil }
        guard consume("/", in: text, at: &cursor) else { return nil }

        let repository = run(of: text, from: &cursor, where: isRepositoryCharacter)
        guard (1...100).contains(repository.count), repository != ".", repository != ".." else { return nil }
        guard consume("#", in: text, at: &cursor) else { return nil }

        let number = run(of: text, from: &cursor, where: { $0.isASCII && $0.isNumber })
        guard !number.isEmpty, number.count <= 9, number.first != "0" else { return nil }
        guard endsToken(text, at: cursor) else { return nil }

        let written = String(text[index..<cursor])
        let url = "https://github.com/\(owner)/\(repository)/issues/\(number)"
        return DetectedLink(range: index..<cursor, text: written, url: url)
    }

    private static func run(
        of text: String, from cursor: inout String.Index, where accepts: (Character) -> Bool
    ) -> String {
        let start = cursor
        while cursor < text.endIndex, accepts(text[cursor]) {
            cursor = text.index(after: cursor)
        }
        return String(text[start..<cursor])
    }

    private static func consume(_ character: Character, in text: String, at cursor: inout String.Index) -> Bool {
        guard cursor < text.endIndex, text[cursor] == character else { return false }
        cursor = text.index(after: cursor)
        return true
    }

    private static func endsToken(_ text: String, at index: String.Index) -> Bool {
        guard index < text.endIndex else { return true }
        let next = text[index]
        if next.isLetter || next.isNumber || next == "#" { return false }
        guard next == "." else { return !glued.contains(next) }
        let after = text.index(after: index)
        return after == text.endIndex || !(text[after].isLetter || text[after].isNumber)
    }

    private static func isOwnerCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || character == "-")
    }

    private static func isRepositoryCharacter(_ character: Character) -> Bool {
        isOwnerCharacter(character) || character == "_" || character == "."
    }
}
