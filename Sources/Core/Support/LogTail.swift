import Foundation

public enum LogTail {
    public static func last(_ text: String, lines: Int) -> String {
        guard lines > 0 else { return "" }

        var end = text.endIndex
        while end > text.startIndex {
            let previous = text.index(before: end)
            guard text[previous].isNewline else { break }
            end = previous
        }
        guard end > text.startIndex else { return "" }

        var start = end
        var seen = 0
        while start > text.startIndex {
            let previous = text.index(before: start)
            if text[previous].isNewline {
                seen += 1
                if seen == lines { break }
            }
            start = previous
        }

        return String(text[start..<end])
    }

    public static func lastLine(_ text: String) -> String {
        let tail = last(text, lines: 1)
        return tail.trimmingCharacters(in: .whitespaces)
    }

    public static func lineCount(_ text: String) -> Int {
        let bytes = text.utf8
        let end = bytes.endIndex

        var total = 0
        var sinceContent = 0
        var sawContent = false

        var index = bytes.startIndex
        while index < end {
            let byte = bytes[index]
            index = bytes.index(after: index)
            if byte == 0x0D {
                total += 1
                sinceContent += 1
                if index < end, bytes[index] == 0x0A { index = bytes.index(after: index) }
            } else if byte == 0x0A {
                total += 1
                sinceContent += 1
            } else {
                sawContent = true
                sinceContent = 0
            }
        }

        guard sawContent else { return 0 }
        return 1 + total - sinceContent
    }
}
