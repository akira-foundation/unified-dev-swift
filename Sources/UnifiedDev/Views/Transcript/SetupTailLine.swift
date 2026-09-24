import Foundation

struct SetupTailLine: Identifiable, Equatable {
    var id: Int
    var text: String

    static func lines(of tail: String, endingAt log: String) -> [SetupTailLine] {
        guard !tail.isEmpty else { return [] }

        var trailing = 0
        var index = log.endIndex
        while index > log.startIndex {
            let previous = log.index(before: index)
            guard log[previous].isNewline else { break }
            trailing += log[previous].utf8.count
            index = previous
        }

        var start = log.utf8.count - tail.utf8.count - trailing
        var result: [SetupTailLine] = []
        var text = ""

        for character in tail {
            if character.isNewline {
                result.append(SetupTailLine(id: start, text: text))
                start += text.utf8.count + character.utf8.count
                text = ""
            } else {
                text.append(character)
            }
        }
        result.append(SetupTailLine(id: start, text: text))
        return result
    }
}
