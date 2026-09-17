import Foundation

public struct ReviewTurnRecord: Sendable, Hashable {
    public struct Chip: Sendable, Hashable {
        public var filePath: String
        public var side: ReviewCommentSide
        public var line: Int
        public var lastLine: Int
        public var body: String

        public var fileName: String { (filePath as NSString).lastPathComponent }

        public var lineDescription: String {
            lastLine > line ? "lines \(line) to \(lastLine)" : "line \(line)"
        }

        public var label: String {
            let condensed = body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return condensed.isEmpty ? fileName : "\(fileName) \(condensed)"
        }

        public init(
            filePath: String,
            side: ReviewCommentSide,
            line: Int,
            lastLine: Int? = nil,
            body: String
        ) {
            self.filePath = filePath
            self.side = side
            self.line = line
            self.lastLine = max(line, lastLine ?? line)
            self.body = body
        }
    }

    public var message: String
    public var chips: [Chip]

    public init(message: String, chips: [Chip]) {
        self.message = message
        self.chips = chips
    }
}

public enum ReviewTurn {
    public static func compose(
        message: String,
        comments: [ReviewComment],
        worktreePath: String?,
        template: String
    ) -> String {
        ReviewPromptContext(message: message, comments: comments, worktreePath: worktreePath)
            .render(template: template).text
    }

    private static let scaffold: [String] = {
        var lines = PromptRegistry.definition(for: .review).defaultTemplate
            .components(separatedBy: "\n")
        guard lines.first == PromptTemplate.token(PromptRegistry.Review.message),
              lines.last == PromptTemplate.token(PromptRegistry.Review.comments)
        else { return [] }
        lines.removeFirst()
        lines.removeLast()
        while lines.first == "" { lines.removeFirst() }
        while lines.last == "" { lines.removeLast() }
        return lines
    }()

    public static func split(_ text: String) -> ReviewTurnRecord? {
        guard !scaffold.isEmpty else { return nil }
        let lines = text.components(separatedBy: "\n")
        guard lines.count > scaffold.count else { return nil }

        var start: Int?
        for candidate in 0...(lines.count - scaffold.count) {
            let run = lines[candidate..<(candidate + scaffold.count)]
            if zip(run, scaffold).allSatisfy({ matches($0, pattern: $1) }) {
                start = candidate
                break
            }
        }
        guard let start, start >= 2, lines[start - 1] == "" else { return nil }

        var message = lines[..<(start - 1)].joined(separator: "\n")
        if message == ReviewPromptContext.noMessage { message = "" }

        var payload = Array(lines[(start + scaffold.count)...])
        while payload.first == "" { payload.removeFirst() }

        guard let chips = chips(from: payload), !chips.isEmpty else { return nil }
        return ReviewTurnRecord(message: message, chips: chips)
    }

    private static func matches(_ line: String, pattern: String) -> Bool {
        guard let token = pattern.range(of: PromptTemplate.token(PromptRegistry.Review.count))
        else { return line == pattern }

        let prefix = pattern[..<token.lowerBound]
        let suffix = pattern[token.upperBound...]
        guard line.count > prefix.count + suffix.count,
              line.hasPrefix(prefix), line.hasSuffix(suffix) else { return false }
        let middle = line.dropFirst(prefix.count).dropLast(suffix.count)
        return !middle.isEmpty && middle.allSatisfy(\.isNumber)
    }

    private static let filePrefix = "## "
    private static let linePrefix = "### Line "
    private static let rangePrefix = "### Lines "
    private static let rangeJoin = " to "
    private static let oldSideSuffix = ", on the removed side of the diff"

    private static func chips(from lines: [String]) -> [ReviewTurnRecord.Chip]? {
        var chips: [ReviewTurnRecord.Chip] = []
        var file: String?
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.isEmpty {
                index += 1
                continue
            }
            if line.hasPrefix(filePrefix) {
                let path = String(line.dropFirst(filePrefix.count))
                guard !path.isEmpty else { return nil }
                file = path
                index += 1
                continue
            }
            if isTruncationTail(line) {
                index += 1
                continue
            }
            guard let (number, last, side) = heading(line), let file else { return nil }
            index += 1
            let body = readBody(lines, from: &index)
            chips.append(ReviewTurnRecord.Chip(
                filePath: file, side: side, line: number, lastLine: last, body: body
            ))
        }
        return chips
    }

    private static func heading(
        _ line: String
    ) -> (line: Int, lastLine: Int, side: ReviewCommentSide)? {
        let isRange = line.hasPrefix(rangePrefix)
        guard isRange || line.hasPrefix(linePrefix) else { return nil }
        var rest = line.dropFirst((isRange ? rangePrefix : linePrefix).count)
        var side = ReviewCommentSide.new
        if rest.hasSuffix(oldSideSuffix) {
            rest = rest.dropLast(oldSideSuffix.count)
            side = .old
        }
        guard isRange else {
            guard let number = wholeNumber(rest) else { return nil }
            return (number, number, side)
        }
        guard let join = rest.range(of: rangeJoin),
              let start = wholeNumber(rest[..<join.lowerBound]),
              let end = wholeNumber(rest[join.upperBound...]),
              end >= start
        else { return nil }
        return (start, end, side)
    }

    private static func wholeNumber(_ text: Substring) -> Int? {
        guard !text.isEmpty, text.allSatisfy(\.isNumber) else { return nil }
        return Int(text)
    }

    private static func isTruncationTail(_ line: String) -> Bool {
        guard line.hasPrefix("...and ") else { return false }
        let rest = line.dropFirst("...and ".count)
        for suffix in [" more comment not shown.", " more comments not shown."]
        where rest.hasSuffix(suffix) {
            let number = rest.dropLast(suffix.count)
            return !number.isEmpty && number.allSatisfy(\.isNumber)
        }
        return false
    }

    private static func readBody(_ lines: [String], from index: inout Int) -> String {
        while index < lines.count, lines[index].isEmpty { index += 1 }

        if index < lines.count, lines[index].hasPrefix("("), lines[index].hasSuffix(")"),
           lines[index].contains("the comment was written") {
            index += 1
            while index < lines.count, lines[index].isEmpty { index += 1 }
        }

        if index < lines.count, lines[index].count >= 3,
           lines[index].allSatisfy({ $0 == "`" }) {
            let fence = lines[index]
            index += 1
            while index < lines.count, lines[index] != fence { index += 1 }
            if index < lines.count { index += 1 }
            while index < lines.count, lines[index].isEmpty { index += 1 }
        }

        var body: [String] = []
        while index < lines.count {
            let line = lines[index]
            if line.isEmpty {
                var lookahead = index + 1
                while lookahead < lines.count, lines[lookahead].isEmpty { lookahead += 1 }
                if lookahead >= lines.count { break }
                let next = lines[lookahead]
                if next.hasPrefix(filePrefix) || heading(next) != nil || isTruncationTail(next) {
                    break
                }
            }
            body.append(line)
            index += 1
        }
        while body.last == "" { body.removeLast() }
        return body.joined(separator: "\n")
    }
}
